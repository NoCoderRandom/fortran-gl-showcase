module app_runtime
  use core_kinds, only: real64
  use core_logger, only: log_info
  use platform_input, only: input_state
  use render_text_renderer, only: text_renderer
  implicit none (type, external)
  private

  integer, parameter :: name_len = 64
  integer, parameter :: max_runtime_scenes = 16

  type(input_state), pointer, save :: runtime_input => null()
  type(text_renderer), pointer, save :: runtime_text => null()
  integer, save :: runtime_scene_total = 0
  integer, save :: runtime_framebuffer_width = 0
  integer, save :: runtime_framebuffer_height = 0
  real(real64), save :: runtime_elapsed_seconds = 0.0_real64
  character(len=name_len), save :: runtime_scene_names(max_runtime_scenes) = ""
  character(len=96), save :: runtime_display_names(max_runtime_scenes) = ""
  character(len=96), save :: runtime_short_descriptions(max_runtime_scenes) = ""
  logical, save :: request_quit = .false.
  logical, save :: request_menu = .false.
  character(len=name_len), save :: requested_scene_name = ""

  public :: runtime_begin_frame
  public :: runtime_draw_text
  public :: runtime_elapsed
  public :: runtime_framebuffer_size
  public :: runtime_log_screenshot_stub
  public :: runtime_measure_text
  public :: runtime_request_menu
  public :: runtime_request_quit
  public :: runtime_request_scene
  public :: runtime_set_scene_catalog
  public :: runtime_scene_count
  public :: runtime_scene_info
  public :: runtime_take_requests
  public :: runtime_text_begin_frame
  public :: runtime_was_pressed
contains
  subroutine runtime_begin_frame(input, text, framebuffer_width, framebuffer_height, elapsed_seconds)
    type(input_state), target, intent(in) :: input
    type(text_renderer), target, intent(inout) :: text
    integer, intent(in), value :: framebuffer_width
    integer, intent(in), value :: framebuffer_height
    real(real64), intent(in), value :: elapsed_seconds

    runtime_input => input
    runtime_text => text
    runtime_framebuffer_width = framebuffer_width
    runtime_framebuffer_height = framebuffer_height
    runtime_elapsed_seconds = elapsed_seconds
    request_quit = .false.
    request_menu = .false.
    requested_scene_name = ""
  end subroutine runtime_begin_frame

  subroutine runtime_set_scene_catalog(scene_count, scene_names, display_names, short_descriptions)
    integer, intent(in), value :: scene_count
    character(len=*), intent(in) :: scene_names(:)
    character(len=*), intent(in) :: display_names(:)
    character(len=*), intent(in) :: short_descriptions(:)
    integer :: index

    runtime_scene_total = scene_count
    runtime_scene_names = ""
    runtime_display_names = ""
    runtime_short_descriptions = ""
    do index = 1, scene_count
      runtime_scene_names(index) = scene_names(index)
      runtime_display_names(index) = display_names(index)
      runtime_short_descriptions(index) = short_descriptions(index)
    end do
  end subroutine runtime_set_scene_catalog

  subroutine runtime_text_begin_frame()
    if (.not. associated(runtime_text)) error stop "Text renderer not bound."
    call runtime_text%begin_frame(runtime_framebuffer_width, runtime_framebuffer_height)
  end subroutine runtime_text_begin_frame

  subroutine runtime_draw_text(text, x_px, y_px, scale, rgba)
    character(len=*), intent(in) :: text
    integer, intent(in), value :: x_px
    integer, intent(in), value :: y_px
    integer, intent(in), value :: scale
    real, intent(in) :: rgba(4)

    if (.not. associated(runtime_text)) error stop "Text renderer not bound."
    call runtime_text%draw(text, x_px, y_px, scale, rgba)
  end subroutine runtime_draw_text

  integer function runtime_measure_text(text, scale) result(width)
    character(len=*), intent(in) :: text
    integer, intent(in), value :: scale

    if (.not. associated(runtime_text)) error stop "Text renderer not bound."
    width = runtime_text%measure(text, scale)
  end function runtime_measure_text

  integer function runtime_scene_count() result(count)
    count = runtime_scene_total
  end function runtime_scene_count

  subroutine runtime_scene_info(index, scene_name, display_name, short_description)
    integer, intent(in), value :: index
    character(len=*), intent(out) :: scene_name
    character(len=*), intent(out) :: display_name
    character(len=*), intent(out) :: short_description

    if (index < 1 .or. index > runtime_scene_total) error stop "Runtime scene index out of range."
    scene_name = runtime_scene_names(index)
    display_name = runtime_display_names(index)
    short_description = runtime_short_descriptions(index)
  end subroutine runtime_scene_info

  logical function runtime_was_pressed(key) result(value)
    integer, intent(in), value :: key

    if (.not. associated(runtime_input)) error stop "Input state not bound."
    value = runtime_input%was_pressed(key)
  end function runtime_was_pressed

  subroutine runtime_request_quit()
    request_quit = .true.
  end subroutine runtime_request_quit

  subroutine runtime_request_menu()
    request_menu = .true.
  end subroutine runtime_request_menu

  subroutine runtime_request_scene(scene_name)
    character(len=*), intent(in) :: scene_name

    requested_scene_name = ""
    requested_scene_name(1:min(len_trim(scene_name), name_len)) = scene_name(1:min(len_trim(scene_name), name_len))
  end subroutine runtime_request_scene

  subroutine runtime_take_requests(quit_requested, menu_requested, scene_name)
    logical, intent(out) :: quit_requested
    logical, intent(out) :: menu_requested
    character(len=*), intent(out) :: scene_name

    quit_requested = request_quit
    menu_requested = request_menu
    scene_name = trim(requested_scene_name)
  end subroutine runtime_take_requests

  subroutine runtime_framebuffer_size(width, height)
    integer, intent(out) :: width
    integer, intent(out) :: height

    width = runtime_framebuffer_width
    height = runtime_framebuffer_height
  end subroutine runtime_framebuffer_size

  real(real64) function runtime_elapsed() result(value)
    value = runtime_elapsed_seconds
  end function runtime_elapsed

  subroutine runtime_log_screenshot_stub()
    call log_info("screenshot: not yet implemented")
  end subroutine runtime_log_screenshot_stub
end module app_runtime
