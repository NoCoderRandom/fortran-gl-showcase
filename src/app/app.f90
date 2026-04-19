module showcase_app
  use, intrinsic :: iso_c_binding, only: c_int
  use app_runtime, only: runtime_begin_frame, runtime_log_screenshot_stub, runtime_set_scene_catalog, runtime_take_requests
  use core_kinds, only: real64
  use core_logger, only: log_info
  use core_timing, only: frame_clock
  use gl_debug, only: enable_gl_debug
  use gl_loader, only: gl_load, gl_viewport
  use menu_scene, only: menu_scene_type
  use platform_input, only: input_state, key_f11, key_f12
  use platform_window, only: glfw_window
  use render_text_renderer, only: text_renderer
  use scene_base, only: scene_type
  use scene_registry, only: scene_registry_type
  implicit none (type, external)
  private

  public :: run_app

  type :: application
    type(glfw_window) :: window
    type(input_state) :: input
    type(frame_clock) :: clock
    type(scene_registry_type) :: registry
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
  subroutine run_app()
    type(application) :: app

    call app%initialize()
    do while (.not. app%window%should_close())
      call app%tick()
    end do
    call app%shutdown()
  end subroutine run_app

  subroutine application_initialize(this)
    class(application), intent(inout) :: this
    character(len=96) :: display_names(16)
    character(len=64) :: scene_names(16)
    character(len=96) :: short_descriptions(16)
    logical :: debug_context
    integer :: index

    debug_context = .false.
#ifdef FGS_DEBUG_BUILD
    debug_context = .true.
#endif

    call this%window%initialize(1280_c_int, 720_c_int, "Fortran GL Showcase", debug_context)
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
    call runtime_begin_frame(this%input, this%text, int(framebuffer_width), int(framebuffer_height), this%elapsed_seconds)
    call this%current_scene%update(this%clock%delta_seconds)
    call this%current_scene%render()
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
    call this%text%destroy()
    call this%window%shutdown()
  end subroutine application_shutdown

  subroutine destroy_current_scene(this)
    class(application), intent(inout) :: this

    if (.not. allocated(this%current_scene)) return
    call this%current_scene%destroy()
    deallocate(this%current_scene)
  end subroutine destroy_current_scene
end module showcase_app
