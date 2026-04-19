module showcase_app
  use, intrinsic :: iso_c_binding, only: c_int
  use core_kinds, only: real64
  use core_logger, only: log_info
  use core_timing, only: frame_clock
  use gl_debug, only: enable_gl_debug
  use gl_loader, only: gl_load, gl_viewport
  use platform_input, only: input_state, key_escape, key_f11
  use platform_window, only: glfw_window
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
    class(scene_type), allocatable :: current_scene
    real(real64) :: stats_accumulator = 0.0_real64
    integer :: stats_frames = 0
  contains
    procedure :: initialize => application_initialize
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
    logical :: debug_context
    character(len=64) :: scene_name

    debug_context = .false.
#ifdef FGS_DEBUG_BUILD
    debug_context = .true.
#endif

    call this%window%initialize(1280_c_int, 720_c_int, "Fortran GL Showcase", debug_context)
    call gl_load(this%window)
    call enable_gl_debug(this%window)
    call this%registry%register_defaults()
    call this%registry%default_scene_name(scene_name)
    call this%registry%create(trim(scene_name), this%current_scene)
    call this%current_scene%init()
    call this%clock%reset()
    call this%current_scene%get_name(scene_name)
    call log_info("Starting scene: " // trim(scene_name))
  end subroutine application_initialize

  subroutine application_tick(this)
    class(application), intent(inout) :: this
    integer(c_int) :: framebuffer_width
    integer(c_int) :: framebuffer_height
    character(len=128) :: stats_line
    real(real64) :: fps

    call this%window%poll_events()
    call this%input%capture(this%window%get_native_handle())

    if (this%input%was_pressed(key_escape)) call this%window%request_close()
    if (this%input%was_pressed(key_f11)) call this%window%toggle_fullscreen()

    call this%clock%step()
    call this%current_scene%update(this%clock%delta_seconds)
    call this%window%get_framebuffer_size(framebuffer_width, framebuffer_height)
    call gl_viewport(0_c_int, 0_c_int, framebuffer_width, framebuffer_height)
    call this%current_scene%render()
    call this%window%swap_buffers()

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

    if (allocated(this%current_scene)) deallocate(this%current_scene)
    call this%window%shutdown()
  end subroutine application_shutdown
end module showcase_app
