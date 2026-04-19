module platform_input
  use, intrinsic :: iso_c_binding, only: c_int, c_ptr
  implicit none (type, external)
  private

  integer(c_int), parameter, public :: key_escape = 256_c_int
  integer(c_int), parameter, public :: key_f11 = 300_c_int
  integer(c_int), parameter :: glfw_press = 1_c_int
  integer(c_int), parameter :: glfw_repeat = 2_c_int
  integer(c_int), parameter :: key_first = 0_c_int
  integer(c_int), parameter :: key_last = 348_c_int

  public :: input_state

  type :: input_state
    logical :: down(key_first:key_last) = .false.
    logical :: pressed(key_first:key_last) = .false.
  contains
    procedure :: capture => input_capture
    procedure :: is_down => input_is_down
    procedure :: was_pressed => input_was_pressed
  end type input_state

  interface
    integer(c_int) function glfwGetKey(window, key) bind(C, name="glfwGetKey")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      integer(c_int), value :: key
    end function glfwGetKey
  end interface
contains
  subroutine input_capture(this, window)
    class(input_state), intent(inout) :: this
    type(c_ptr), intent(in), value :: window
    integer(c_int) :: key
    integer(c_int) :: state
    logical :: now_down
    logical :: previous_down

    do key = key_first, key_last
      previous_down = this%down(key)
      state = glfwGetKey(window, key)
      now_down = state == glfw_press .or. state == glfw_repeat
      this%down(key) = now_down
      this%pressed(key) = now_down .and. (.not. previous_down)
    end do
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
end module platform_input

