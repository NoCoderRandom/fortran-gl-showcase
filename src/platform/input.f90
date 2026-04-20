module platform_input
  use, intrinsic :: iso_c_binding, only: c_associated, c_double, c_funloc, c_int, c_null_ptr, c_ptr
  implicit none (type, external)
  private

  integer(c_int), parameter, public :: key_a = 65_c_int
  integer(c_int), parameter, public :: key_1 = 49_c_int
  integer(c_int), parameter, public :: key_2 = 50_c_int
  integer(c_int), parameter, public :: key_3 = 51_c_int
  integer(c_int), parameter, public :: key_d = 68_c_int
  integer(c_int), parameter, public :: key_e = 69_c_int
  integer(c_int), parameter, public :: key_escape = 256_c_int
  integer(c_int), parameter, public :: key_enter = 257_c_int
  integer(c_int), parameter, public :: key_f = 70_c_int
  integer(c_int), parameter, public :: key_h = 72_c_int
  integer(c_int), parameter, public :: key_left = 263_c_int
  integer(c_int), parameter, public :: key_left_bracket = 91_c_int
  integer(c_int), parameter, public :: key_right = 262_c_int
  integer(c_int), parameter, public :: key_up = 265_c_int
  integer(c_int), parameter, public :: key_down = 264_c_int
  integer(c_int), parameter, public :: key_page_up = 266_c_int
  integer(c_int), parameter, public :: key_page_down = 267_c_int
  integer(c_int), parameter, public :: key_period = 46_c_int
  integer(c_int), parameter, public :: key_q = 81_c_int
  integer(c_int), parameter, public :: key_r = 82_c_int
  integer(c_int), parameter, public :: key_right_bracket = 93_c_int
  integer(c_int), parameter, public :: key_space = 32_c_int
  integer(c_int), parameter, public :: key_t = 84_c_int
  integer(c_int), parameter, public :: key_v = 86_c_int
  integer(c_int), parameter, public :: key_w = 87_c_int
  integer(c_int), parameter, public :: key_s = 83_c_int
  integer(c_int), parameter, public :: key_f11 = 300_c_int
  integer(c_int), parameter, public :: key_f12 = 301_c_int
  integer(c_int), parameter, public :: mouse_button_left = 0_c_int
  integer(c_int), parameter :: glfw_press = 1_c_int
  integer(c_int), parameter :: glfw_repeat = 2_c_int
  integer(c_int), parameter :: key_first = 0_c_int
  integer(c_int), parameter :: key_last = 348_c_int
  integer(c_int), parameter :: mouse_button_first = 0_c_int
  integer(c_int), parameter :: mouse_button_last = 7_c_int

  public :: input_state

  type :: input_state
    logical :: down(key_first:key_last) = .false.
    logical :: pressed(key_first:key_last) = .false.
    logical :: mouse_down(mouse_button_first:mouse_button_last) = .false.
    logical :: mouse_pressed(mouse_button_first:mouse_button_last) = .false.
    logical :: cursor_initialized = .false.
    real(c_double) :: mouse_x = 0.0_c_double
    real(c_double) :: mouse_y = 0.0_c_double
    real(c_double) :: mouse_dx = 0.0_c_double
    real(c_double) :: mouse_dy = 0.0_c_double
    real(c_double) :: scroll_x = 0.0_c_double
    real(c_double) :: scroll_y = 0.0_c_double
    real(c_double) :: pending_scroll_x = 0.0_c_double
    real(c_double) :: pending_scroll_y = 0.0_c_double
    type(c_ptr) :: bound_window = c_null_ptr
  contains
    procedure :: bind => input_bind
    procedure :: capture => input_capture
    procedure :: is_down => input_is_down
    procedure :: mouse_is_down => input_mouse_is_down
    procedure :: mouse_delta => input_mouse_delta
    procedure :: mouse_position => input_mouse_position
    procedure :: mouse_was_pressed => input_mouse_was_pressed
    procedure :: scroll_delta => input_scroll_delta
    procedure :: was_pressed => input_was_pressed
  end type input_state

  type(input_state), pointer, save :: active_input => null()

  interface
    integer(c_int) function glfwGetKey(window, key) bind(C, name="glfwGetKey")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      integer(c_int), value :: key
    end function glfwGetKey

    subroutine glfwGetCursorPos(window, xpos, ypos) bind(C, name="glfwGetCursorPos")
      import :: c_double, c_ptr
      type(c_ptr), value :: window
      real(c_double), intent(out) :: xpos
      real(c_double), intent(out) :: ypos
    end subroutine glfwGetCursorPos

    integer(c_int) function glfwGetMouseButton(window, button) bind(C, name="glfwGetMouseButton")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      integer(c_int), value :: button
    end function glfwGetMouseButton

    type(c_ptr) function glfwSetScrollCallback(window, callback) result(previous) bind(C, name="glfwSetScrollCallback")
      import :: c_ptr
      type(c_ptr), value :: window
      type(c_ptr), value :: callback
    end function glfwSetScrollCallback
  end interface
contains
  subroutine input_bind(this, window)
    class(input_state), target, intent(inout) :: this
    type(c_ptr), intent(in), value :: window
    type(c_ptr) :: previous

    if (c_associated(this%bound_window, window)) return
    active_input => this
    previous = glfwSetScrollCallback(window, c_funloc(input_scroll_callback))
    if (.false.) print *, c_associated(previous)
    this%bound_window = window
  end subroutine input_bind

  subroutine input_capture(this, window)
    class(input_state), intent(inout) :: this
    type(c_ptr), intent(in), value :: window
    integer(c_int) :: button
    integer(c_int) :: key
    logical :: now_down
    logical :: previous_down
    real(c_double) :: xpos
    real(c_double) :: ypos
    integer(c_int) :: state

    do key = key_first, key_last
      previous_down = this%down(key)
      state = glfwGetKey(window, key)
      now_down = state == glfw_press .or. state == glfw_repeat
      this%down(key) = now_down
      this%pressed(key) = now_down .and. (.not. previous_down)
    end do

    do button = mouse_button_first, mouse_button_last
      previous_down = this%mouse_down(button)
      state = glfwGetMouseButton(window, button)
      now_down = state == glfw_press
      this%mouse_down(button) = now_down
      this%mouse_pressed(button) = now_down .and. (.not. previous_down)
    end do

    call glfwGetCursorPos(window, xpos, ypos)
    if (.not. this%cursor_initialized) then
      this%mouse_dx = 0.0_c_double
      this%mouse_dy = 0.0_c_double
      this%cursor_initialized = .true.
    else
      this%mouse_dx = xpos - this%mouse_x
      this%mouse_dy = ypos - this%mouse_y
    end if
    this%mouse_x = xpos
    this%mouse_y = ypos
    this%scroll_x = this%pending_scroll_x
    this%scroll_y = this%pending_scroll_y
    this%pending_scroll_x = 0.0_c_double
    this%pending_scroll_y = 0.0_c_double
  end subroutine input_capture

  logical function input_is_down(this, key) result(value)
    class(input_state), intent(in) :: this
    integer(c_int), intent(in), value :: key

    value = key >= key_first .and. key <= key_last .and. this%down(key)
  end function input_is_down

  logical function input_was_pressed(this, key) result(value)
    class(input_state), intent(in) :: this
    integer(c_int), intent(in), value :: key

    value = key >= key_first .and. key <= key_last .and. this%pressed(key)
  end function input_was_pressed

  logical function input_mouse_was_pressed(this, button) result(value)
    class(input_state), intent(in) :: this
    integer(c_int), intent(in), value :: button

    value = button >= mouse_button_first .and. button <= mouse_button_last .and. this%mouse_pressed(button)
  end function input_mouse_was_pressed

  logical function input_mouse_is_down(this, button) result(value)
    class(input_state), intent(in) :: this
    integer(c_int), intent(in), value :: button

    value = button >= mouse_button_first .and. button <= mouse_button_last .and. this%mouse_down(button)
  end function input_mouse_is_down

  subroutine input_mouse_position(this, x, y)
    class(input_state), intent(in) :: this
    real(c_double), intent(out) :: x
    real(c_double), intent(out) :: y

    x = this%mouse_x
    y = this%mouse_y
  end subroutine input_mouse_position

  subroutine input_mouse_delta(this, dx, dy)
    class(input_state), intent(in) :: this
    real(c_double), intent(out) :: dx
    real(c_double), intent(out) :: dy

    dx = this%mouse_dx
    dy = this%mouse_dy
  end subroutine input_mouse_delta

  subroutine input_scroll_delta(this, dx, dy)
    class(input_state), intent(in) :: this
    real(c_double), intent(out) :: dx
    real(c_double), intent(out) :: dy

    dx = this%scroll_x
    dy = this%scroll_y
  end subroutine input_scroll_delta

  subroutine input_scroll_callback(window, xoffset, yoffset) bind(C)
    type(c_ptr), value :: window
    real(c_double), value :: xoffset
    real(c_double), value :: yoffset

    if (.not. associated(active_input)) return
    if (.not. c_associated(active_input%bound_window, window)) return
    active_input%pending_scroll_x = active_input%pending_scroll_x + xoffset
    active_input%pending_scroll_y = active_input%pending_scroll_y + yoffset
  end subroutine input_scroll_callback
end module platform_input
