module showcase_app
  use, intrinsic :: iso_c_binding, only: c_int, c_loc
  use app_runtime, only: runtime_begin_frame, runtime_log_screenshot_stub, runtime_set_scene_catalog, runtime_take_requests
  use core_frame_export, only: export_rgba_frame_png
  use core_kinds, only: real64
  use core_logger, only: log_info
  use core_timing, only: frame_clock
  use gl_debug, only: enable_gl_debug
  use gl_loader, only: gl_load, gl_read_pixels, gl_rgba, gl_unsigned_byte, gl_viewport
  use menu_scene, only: menu_scene_type
  use platform_input, only: input_state, key_f11, key_f12
  use platform_window, only: glfw_window
  use render_post_process, only: post_process
  use render_text_renderer, only: text_renderer
  use scene_base, only: scene_type
  use scene_registry, only: scene_registry_type
  implicit none (type, external)
  private

  public :: render_request
  public :: run_app
  public :: run_render

  type :: render_request
    character(len=:), allocatable :: output_dir
    character(len=:), allocatable :: scene_name
    real(real64) :: seconds = 0.0_real64
    integer :: fps = 0
    integer :: width = 1280
    integer :: height = 720
  end type render_request

  type :: application
    type(glfw_window) :: window
    type(input_state) :: input
    type(frame_clock) :: clock
    type(scene_registry_type) :: registry
    type(post_process) :: post
    type(text_renderer) :: text
    class(scene_type), allocatable :: current_scene
    real(real64) :: elapsed_seconds = 0.0_real64
    real(real64) :: stats_accumulator = 0.0_real64
    integer :: stats_frames = 0
  contains
    procedure :: initialize => application_initialize
    procedure :: open_menu => application_open_menu
    procedure :: open_scene => application_open_scene
    procedure :: shutdown => application_shutdown
    procedure :: tick => application_tick
  end type application
contains
  subroutine run_app(initial_scene_name)
    character(len=*), intent(in), optional :: initial_scene_name
    type(application) :: app

    call app%initialize()
    if (present(initial_scene_name)) then
      if (len_trim(initial_scene_name) > 0) call app%open_scene(trim(initial_scene_name))
    end if
    do while (.not. app%window%should_close())
      call app%tick()
    end do
    call app%shutdown()
  end subroutine run_app

  subroutine run_render(request)
    type(render_request), intent(in) :: request
    type(application) :: app
    character(len=128) :: progress_line
    integer(c_int) :: framebuffer_height
    integer(c_int) :: framebuffer_width
    integer :: frame_count
    integer :: frame_index
    integer :: progress_percent
    real(real64) :: delta_seconds
    real(real64) :: target_time
    integer(1), allocatable, target :: pixels(:)

    if (request%fps <= 0 .or. request%seconds <= 0.0_real64) error stop "Invalid render request."
    call app%initialize(int(request%width, c_int), int(request%height, c_int), visible=.false., swap_interval=0_c_int)
    if (.not. render_scene_allowed(trim(request%scene_name))) then
      error stop "Requested scene is not marked offline-capable."
    end if
    call app%open_scene(trim(request%scene_name))
    frame_count = int(request%seconds * real(request%fps, real64))
    if (frame_count <= 0) error stop "Render request produced no frames."
    delta_seconds = 1.0_real64 / real(request%fps, real64)
    allocate(pixels(4 * request%width * request%height))
    call ensure_directory(trim(request%output_dir))

    do frame_index = 0, frame_count - 1
      target_time = real(frame_index, real64) * delta_seconds
      app%elapsed_seconds = target_time
      call app%window%get_framebuffer_size(framebuffer_width, framebuffer_height)
      call gl_viewport(0_c_int, 0_c_int, framebuffer_width, framebuffer_height)
      call runtime_begin_frame( &
        app%input, app%text, int(framebuffer_width), int(framebuffer_height), app%elapsed_seconds, .true. &
      )
      call app%current_scene%update(delta_seconds)
      call app%post%begin_scene_target(int(framebuffer_width), int(framebuffer_height))
      call app%current_scene%render()
      call app%post%end_and_present(app%current_scene%get_post_settings(), real(app%elapsed_seconds))
      call gl_read_pixels(0_c_int, 0_c_int, framebuffer_width, framebuffer_height, gl_rgba, gl_unsigned_byte, c_loc(pixels))
      call export_rgba_frame_png(trim(request%output_dir), frame_index, int(framebuffer_width), int(framebuffer_height), pixels)
      if (mod(frame_index + 1, 30) == 0 .or. frame_index == frame_count - 1) then
        progress_percent = int(100.0_real64 * real(frame_index + 1, real64) / real(frame_count, real64))
        write (progress_line, '(a,i0,a,i0,a,i0,a)') "frame ", frame_index + 1, "/", frame_count, " (", progress_percent, "%)"
        call log_info(trim(progress_line))
      end if
    end do

    deallocate(pixels)
    call app%shutdown()
  end subroutine run_render

  subroutine application_initialize(this, width, height, visible, swap_interval)
    class(application), intent(inout) :: this
    integer(c_int), intent(in), optional :: width
    integer(c_int), intent(in), optional :: height
    logical, intent(in), optional :: visible
    integer(c_int), intent(in), optional :: swap_interval
    character(len=96) :: display_names(16)
    character(len=64) :: scene_names(16)
    character(len=96) :: short_descriptions(16)
    logical :: debug_context
    integer :: index
    integer(c_int) :: init_height
    integer(c_int) :: init_width

    debug_context = .false.
#ifdef FGS_DEBUG_BUILD
    debug_context = .true.
#endif
    init_width = 1280_c_int
    init_height = 720_c_int
    if (present(width)) init_width = width
    if (present(height)) init_height = height

    call this%window%initialize(init_width, init_height, "Fortran GL Showcase", debug_context, visible, swap_interval)
    call this%input%bind(this%window%get_native_handle())
    call gl_load(this%window)
    call enable_gl_debug(this%window)
    call this%registry%register_defaults()
    do index = 1, this%registry%count_entries()
      call this%registry%describe(index, scene_names(index), display_names(index), short_descriptions(index))
    end do
    call runtime_set_scene_catalog(this%registry%count_entries(), scene_names, display_names, short_descriptions)
    call this%text%initialize()
    call this%open_menu()
    call this%clock%reset()
    call log_info("Starting scene: menu_scene")
  end subroutine application_initialize

  subroutine application_open_menu(this)
    class(application), intent(inout) :: this

    call destroy_current_scene(this)
    allocate(menu_scene_type :: this%current_scene)
    call this%current_scene%init()
  end subroutine application_open_menu

  subroutine application_open_scene(this, scene_name)
    class(application), intent(inout) :: this
    character(len=*), intent(in) :: scene_name

    call destroy_current_scene(this)
    call this%registry%create(trim(scene_name), this%current_scene)
    call this%current_scene%init()
  end subroutine application_open_scene

  subroutine application_tick(this)
    class(application), intent(inout) :: this
    character(len=64) :: requested_scene
    character(len=128) :: stats_line
    integer(c_int) :: framebuffer_height
    integer(c_int) :: framebuffer_width
    logical :: request_menu
    logical :: request_quit
    real(real64) :: fps

    call this%window%poll_events()
    call this%input%capture(this%window%get_native_handle())

    if (this%input%was_pressed(key_f11)) call this%window%toggle_fullscreen()
    if (this%input%was_pressed(key_f12)) call runtime_log_screenshot_stub()

    call this%clock%step()
    this%elapsed_seconds = this%elapsed_seconds + this%clock%delta_seconds
    call this%window%get_framebuffer_size(framebuffer_width, framebuffer_height)
    call gl_viewport(0_c_int, 0_c_int, framebuffer_width, framebuffer_height)
    call runtime_begin_frame( &
      this%input, this%text, int(framebuffer_width), int(framebuffer_height), this%elapsed_seconds, .false. &
    )
    call this%current_scene%update(this%clock%delta_seconds)
    call this%post%begin_scene_target(int(framebuffer_width), int(framebuffer_height))
    call this%current_scene%render()
    call this%post%end_and_present(this%current_scene%get_post_settings(), real(this%elapsed_seconds))
    call this%window%swap_buffers()
    call runtime_take_requests(request_quit, request_menu, requested_scene)

    if (request_quit) call this%window%request_close()
    if (request_menu) call this%open_menu()
    if (len_trim(requested_scene) > 0) call this%open_scene(trim(requested_scene))

    this%stats_accumulator = this%stats_accumulator + this%clock%delta_seconds
    this%stats_frames = this%stats_frames + 1
    if (this%stats_accumulator >= 1.0_real64) then
      fps = real(this%stats_frames, real64) / this%stats_accumulator
      write (stats_line, '(a,f7.2,a,f7.2)') &
        'frame_ms=', this%clock%delta_seconds * 1000.0_real64, ' fps=', fps
      call log_info(trim(stats_line))
      this%stats_accumulator = 0.0_real64
      this%stats_frames = 0
    end if
  end subroutine application_tick

  subroutine application_shutdown(this)
    class(application), intent(inout) :: this

    call destroy_current_scene(this)
    call this%post%destroy()
    call this%text%destroy()
    call this%window%shutdown()
  end subroutine application_shutdown

  subroutine destroy_current_scene(this)
    class(application), intent(inout) :: this

    if (.not. allocated(this%current_scene)) return
    call this%current_scene%destroy()
    deallocate(this%current_scene)
  end subroutine destroy_current_scene

  subroutine ensure_directory(path)
    character(len=*), intent(in) :: path
    integer :: status

    call execute_command_line("mkdir -p '"//trim(path)//"'", exitstat=status)
    if (status /= 0) error stop "Failed to create output directory."
  end subroutine ensure_directory

  logical function render_scene_allowed(scene_name) result(allowed)
    character(len=*), intent(in) :: scene_name

    select case (trim(scene_name))
    case ("fractal_explorer", "mandelbulb_cathedral", "particle_galaxy", "combined_showcase")
      allowed = .true.
    case default
      allowed = .false.
    end select
  end function render_scene_allowed
end module showcase_app
