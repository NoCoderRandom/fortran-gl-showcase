module gl_debug
  use, intrinsic :: iso_c_binding, only: c_associated, c_ptr
  use core_logger, only: log_info
  use platform_window, only: glfw_window
  implicit none (type, external)
  private

  public :: enable_gl_debug
contains
  subroutine enable_gl_debug(window)
    class(glfw_window), intent(inout) :: window
    type(c_ptr) :: handle

    call log_info("OpenGL debug callback is reserved for a later prompt.")
    handle = window%get_native_handle()
    if (c_associated(handle)) return
  end subroutine enable_gl_debug
end module gl_debug
