module gl_loader
  use, intrinsic :: iso_c_binding, only: c_associated, c_float, c_int, c_ptr
  use platform_window, only: glfw_window
  implicit none (type, external)
  private

  integer(c_int), parameter, public :: gl_color_buffer_bit = int(z'00004000', c_int)

  public :: gl_clear
  public :: gl_clear_color
  public :: gl_load
  public :: gl_viewport

  interface
    subroutine gl_clear_color(red, green, blue, alpha) bind(C, name="glClearColor")
      import :: c_float
      real(c_float), value :: red
      real(c_float), value :: green
      real(c_float), value :: blue
      real(c_float), value :: alpha
    end subroutine gl_clear_color

    subroutine gl_clear(mask) bind(C, name="glClear")
      import :: c_int
      integer(c_int), value :: mask
    end subroutine gl_clear

    subroutine gl_viewport(x, y, width, height) bind(C, name="glViewport")
      import :: c_int
      integer(c_int), value :: x
      integer(c_int), value :: y
      integer(c_int), value :: width
      integer(c_int), value :: height
    end subroutine gl_viewport
  end interface
contains
  subroutine gl_load(window)
    class(glfw_window), intent(inout) :: window
    type(c_ptr) :: handle

    handle = window%get_native_handle()
    if (c_associated(handle)) return
  end subroutine gl_load
end module gl_loader
