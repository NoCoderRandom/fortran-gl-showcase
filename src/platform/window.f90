module platform_window
  use, intrinsic :: iso_c_binding, only: &
    c_associated, c_char, c_f_pointer, c_int, c_null_char, c_null_ptr, c_ptr
  implicit none (type, external)
  private

  integer(c_int), parameter :: glfw_context_version_major = int(z'00022002', c_int)
  integer(c_int), parameter :: glfw_context_version_minor = int(z'00022003', c_int)
  integer(c_int), parameter :: glfw_opengl_profile = int(z'00022008', c_int)
  integer(c_int), parameter :: glfw_opengl_core_profile = int(z'00032001', c_int)
  integer(c_int), parameter :: glfw_opengl_debug_context = int(z'00022027', c_int)

  public :: glfw_window

  type, bind(C) :: glfw_vidmode
    integer(c_int) :: width
    integer(c_int) :: height
    integer(c_int) :: red_bits
    integer(c_int) :: green_bits
    integer(c_int) :: blue_bits
    integer(c_int) :: refresh_rate
  end type glfw_vidmode

  type :: glfw_window
    type(c_ptr) :: handle = c_null_ptr
    logical :: fullscreen = .false.
    integer(c_int) :: windowed_x = 100_c_int
    integer(c_int) :: windowed_y = 100_c_int
    integer(c_int) :: windowed_width = 1280_c_int
    integer(c_int) :: windowed_height = 720_c_int
  contains
    procedure :: get_framebuffer_size => glfw_window_get_framebuffer_size
    procedure :: get_native_handle => glfw_window_get_native_handle
    procedure :: initialize => glfw_window_initialize
    procedure :: poll_events => glfw_window_poll_events
    procedure :: request_close => glfw_window_request_close
    procedure :: should_close => glfw_window_should_close
    procedure :: shutdown => glfw_window_shutdown
    procedure :: swap_buffers => glfw_window_swap_buffers
    procedure :: toggle_fullscreen => glfw_window_toggle_fullscreen
  end type glfw_window

  interface
    integer(c_int) function glfwInit() bind(C, name="glfwInit")
      import :: c_int
    end function glfwInit

    subroutine glfwTerminate() bind(C, name="glfwTerminate")
    end subroutine glfwTerminate

    subroutine glfwWindowHint(hint, value) bind(C, name="glfwWindowHint")
      import :: c_int
      integer(c_int), value :: hint
      integer(c_int), value :: value
    end subroutine glfwWindowHint

    type(c_ptr) function glfwCreateWindow(width, height, title, monitor, share) bind(C, name="glfwCreateWindow")
      import :: c_char, c_int, c_ptr
      integer(c_int), value :: width
      integer(c_int), value :: height
      character(kind=c_char), intent(in) :: title(*)
      type(c_ptr), value :: monitor
      type(c_ptr), value :: share
    end function glfwCreateWindow

    subroutine glfwDestroyWindow(window) bind(C, name="glfwDestroyWindow")
      import :: c_ptr
      type(c_ptr), value :: window
    end subroutine glfwDestroyWindow

    subroutine glfwMakeContextCurrent(window) bind(C, name="glfwMakeContextCurrent")
      import :: c_ptr
      type(c_ptr), value :: window
    end subroutine glfwMakeContextCurrent

    subroutine glfwSwapBuffers(window) bind(C, name="glfwSwapBuffers")
      import :: c_ptr
      type(c_ptr), value :: window
    end subroutine glfwSwapBuffers

    subroutine glfwPollEvents() bind(C, name="glfwPollEvents")
    end subroutine glfwPollEvents

    integer(c_int) function glfwWindowShouldClose(window) bind(C, name="glfwWindowShouldClose")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
    end function glfwWindowShouldClose

    subroutine glfwSetWindowShouldClose(window, value) bind(C, name="glfwSetWindowShouldClose")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      integer(c_int), value :: value
    end subroutine glfwSetWindowShouldClose

    subroutine glfwSwapInterval(interval) bind(C, name="glfwSwapInterval")
      import :: c_int
      integer(c_int), value :: interval
    end subroutine glfwSwapInterval

    type(c_ptr) function glfwGetPrimaryMonitor() bind(C, name="glfwGetPrimaryMonitor")
      import :: c_ptr
    end function glfwGetPrimaryMonitor

    type(c_ptr) function glfwGetVideoMode(monitor) bind(C, name="glfwGetVideoMode")
      import :: c_ptr
      type(c_ptr), value :: monitor
    end function glfwGetVideoMode

    subroutine glfwGetWindowPos(window, xpos, ypos) bind(C, name="glfwGetWindowPos")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      integer(c_int), intent(out) :: xpos
      integer(c_int), intent(out) :: ypos
    end subroutine glfwGetWindowPos

    subroutine glfwGetWindowSize(window, width, height) bind(C, name="glfwGetWindowSize")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      integer(c_int), intent(out) :: width
      integer(c_int), intent(out) :: height
    end subroutine glfwGetWindowSize

    subroutine glfwSetWindowMonitor(window, monitor, xpos, ypos, width, height, refresh_rate) bind(C, name="glfwSetWindowMonitor")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      type(c_ptr), value :: monitor
      integer(c_int), value :: xpos
      integer(c_int), value :: ypos
      integer(c_int), value :: width
      integer(c_int), value :: height
      integer(c_int), value :: refresh_rate
    end subroutine glfwSetWindowMonitor

    subroutine glfwGetFramebufferSize(window, width, height) bind(C, name="glfwGetFramebufferSize")
      import :: c_int, c_ptr
      type(c_ptr), value :: window
      integer(c_int), intent(out) :: width
      integer(c_int), intent(out) :: height
    end subroutine glfwGetFramebufferSize
  end interface
contains
  subroutine glfw_window_initialize(this, width, height, title, debug_context)
    class(glfw_window), intent(inout) :: this
    integer(c_int), intent(in), value :: width
    integer(c_int), intent(in), value :: height
    character(len=*), intent(in) :: title
    logical, intent(in), value :: debug_context
    character(kind=c_char, len=:), allocatable :: c_title

    if (glfwInit() == 0_c_int) error stop "GLFW initialization failed."
    call glfwWindowHint(glfw_context_version_major, 4_c_int)
    call glfwWindowHint(glfw_context_version_minor, 6_c_int)
    call glfwWindowHint(glfw_opengl_profile, glfw_opengl_core_profile)
    call glfwWindowHint(glfw_opengl_debug_context, merge(1_c_int, 0_c_int, debug_context))

    c_title = to_c_string(title)
    this%handle = glfwCreateWindow(width, height, c_title, c_null_ptr, c_null_ptr)
    if (.not. c_associated(this%handle)) error stop "Window creation failed."

    this%windowed_width = width
    this%windowed_height = height
    call glfwMakeContextCurrent(this%handle)
    call glfwSwapInterval(1_c_int)
  end subroutine glfw_window_initialize

  subroutine glfw_window_poll_events(this)
    class(glfw_window), intent(inout) :: this

    if (.not. c_associated(this%handle)) return
    call glfwPollEvents()
  end subroutine glfw_window_poll_events

  subroutine glfw_window_swap_buffers(this)
    class(glfw_window), intent(inout) :: this

    if (.not. c_associated(this%handle)) return
    call glfwSwapBuffers(this%handle)
  end subroutine glfw_window_swap_buffers

  logical function glfw_window_should_close(this) result(value)
    class(glfw_window), intent(in) :: this

    if (.not. c_associated(this%handle)) then
      value = .true.
      return
    end if
    value = glfwWindowShouldClose(this%handle) /= 0_c_int
  end function glfw_window_should_close

  subroutine glfw_window_request_close(this)
    class(glfw_window), intent(inout) :: this

    if (.not. c_associated(this%handle)) return
    call glfwSetWindowShouldClose(this%handle, 1_c_int)
  end subroutine glfw_window_request_close

  subroutine glfw_window_toggle_fullscreen(this)
    class(glfw_window), intent(inout) :: this
    type(c_ptr) :: monitor
    type(c_ptr) :: video_mode_ptr
    type(glfw_vidmode), pointer :: video_mode

    if (.not. c_associated(this%handle)) return

    if (.not. this%fullscreen) then
      call glfwGetWindowPos(this%handle, this%windowed_x, this%windowed_y)
      call glfwGetWindowSize(this%handle, this%windowed_width, this%windowed_height)
      monitor = glfwGetPrimaryMonitor()
      video_mode_ptr = glfwGetVideoMode(monitor)
      if (.not. c_associated(video_mode_ptr)) return
      call c_f_pointer(video_mode_ptr, video_mode)
      call glfwSetWindowMonitor(this%handle, monitor, 0_c_int, 0_c_int, &
        video_mode%width, video_mode%height, video_mode%refresh_rate)
      this%fullscreen = .true.
    else
      call glfwSetWindowMonitor(this%handle, c_null_ptr, this%windowed_x, this%windowed_y, &
        this%windowed_width, this%windowed_height, 0_c_int)
      this%fullscreen = .false.
    end if
  end subroutine glfw_window_toggle_fullscreen

  subroutine glfw_window_get_framebuffer_size(this, width, height)
    class(glfw_window), intent(inout) :: this
    integer(c_int), intent(out) :: width
    integer(c_int), intent(out) :: height

    if (.not. c_associated(this%handle)) then
      width = 0_c_int
      height = 0_c_int
      return
    end if
    call glfwGetFramebufferSize(this%handle, width, height)
  end subroutine glfw_window_get_framebuffer_size

  function glfw_window_get_native_handle(this) result(handle)
    class(glfw_window), intent(inout) :: this
    type(c_ptr) :: handle

    handle = this%handle
  end function glfw_window_get_native_handle

  subroutine glfw_window_shutdown(this)
    class(glfw_window), intent(inout) :: this

    if (c_associated(this%handle)) then
      call glfwDestroyWindow(this%handle)
      this%handle = c_null_ptr
    end if
    call glfwTerminate()
  end subroutine glfw_window_shutdown

  pure function to_c_string(text) result(c_text)
    character(len=*), intent(in) :: text
    character(kind=c_char, len=len_trim(text) + 1) :: c_text

    c_text = trim(text) // c_null_char
  end function to_c_string
end module platform_window

