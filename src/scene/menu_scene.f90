module menu_scene
  use, intrinsic :: iso_c_binding, only: c_float
  use app_runtime, only: runtime_draw_text, runtime_elapsed, runtime_framebuffer_size, runtime_measure_text, runtime_request_quit, &
    runtime_request_scene, runtime_scene_count, runtime_scene_info, runtime_was_pressed
  use core_kinds, only: real64
  use platform_input, only: key_down, key_enter, key_escape, key_s, key_up, key_w
  use render_menu_background, only: menu_background_renderer
  use scene_base, only: scene_type
  implicit none (type, external)
  private

  public :: menu_scene_type

  type, extends(scene_type) :: menu_scene_type
    type(menu_background_renderer) :: background
    integer :: selected_index = 1
  contains
    procedure :: destroy => menu_destroy
    procedure :: get_name => menu_get_name
    procedure :: init => menu_init
    procedure :: render => menu_render
    procedure :: update => menu_update
  end type menu_scene_type
contains
  subroutine menu_destroy(this)
    class(menu_scene_type), intent(inout) :: this

    call this%background%destroy()
  end subroutine menu_destroy

  subroutine menu_get_name(this, value)
    class(menu_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "menu_scene"
  end subroutine menu_get_name

  subroutine menu_init(this)
    class(menu_scene_type), intent(inout) :: this

    this%selected_index = 1
    call this%background%initialize()
  end subroutine menu_init

  subroutine menu_update(this, delta_seconds)
    class(menu_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds
    character(len=64) :: scene_name
    character(len=96) :: display_name
    character(len=96) :: short_description
    logical :: move_down
    logical :: move_up
    integer :: scene_count

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."

    scene_count = runtime_scene_count()
    move_up = runtime_was_pressed(key_up)
    if (.not. move_up) move_up = runtime_was_pressed(key_w)
    if (move_up) then
      this%selected_index = this%selected_index - 1
      if (this%selected_index < 1) this%selected_index = scene_count
    end if

    move_down = runtime_was_pressed(key_down)
    if (.not. move_down) move_down = runtime_was_pressed(key_s)
    if (move_down) then
      this%selected_index = this%selected_index + 1
      if (this%selected_index > scene_count) this%selected_index = 1
    end if

    if (runtime_was_pressed(key_enter)) then
      call runtime_scene_info(this%selected_index, scene_name, display_name, short_description)
      call runtime_request_scene(trim(scene_name))
    end if

    if (runtime_was_pressed(key_escape)) call runtime_request_quit()
  end subroutine menu_update

  subroutine menu_render(this)
    class(menu_scene_type), intent(inout) :: this
    character(len=*), parameter :: footer_text = &
      "W/S OR UP/DN  NAVIGATE   ENTER  SELECT   ESC  BACK   F11  FULLSCREEN   F12  SCREENSHOT"
    character(len=*), parameter :: subtitle_text = &
      "MODERN FORTRAN 2018 / 2023  *  OPENGL 4.6  *  WSL2 + NVIDIA"
    character(len=64) :: scene_name
    character(len=96) :: display_name
    character(len=96) :: short_description
    character(len=128) :: line
    integer :: entry_y
    integer :: footer_x
    integer :: index
    integer :: scene_count
    integer :: width
    integer :: height
    real(c_float) :: accent(4)
    real(c_float) :: body(4)
    real(c_float) :: dim(4)

    call this%background%draw(real(runtime_elapsed(), c_float))
    call runtime_framebuffer_size(width, height)

    accent = [0.95_c_float, 0.83_c_float, 0.43_c_float, 1.0_c_float]
    body = [0.84_c_float, 0.87_c_float, 0.92_c_float, 1.0_c_float]
    dim = [0.54_c_float, 0.58_c_float, 0.66_c_float, 1.0_c_float]

    call runtime_draw_text("FORTRAN GL SHOWCASE", &
      (width - runtime_measure_text("FORTRAN GL SHOWCASE", 4)) / 2, height / 7, 4, accent)
    call runtime_draw_text(subtitle_text, &
      max(24, (width - runtime_measure_text(subtitle_text, 1)) / 2), &
      height / 7 + 56, 1, dim)

    scene_count = runtime_scene_count()
    do index = 1, scene_count
      call runtime_scene_info(index, scene_name, display_name, short_description)
      write (line, '(i1,a,1x,a,2x,a,1x,a)') index, ".", trim(display_name), "-", trim(short_description)
      entry_y = height / 3 + (index - 1) * 28
      if (index == this%selected_index) then
        call runtime_draw_text("> "//trim(line), 70, entry_y, 1, accent)
      else
        call runtime_draw_text("  "//trim(line), 70, entry_y, 1, body)
      end if
    end do

    footer_x = max(16, (width - runtime_measure_text(footer_text, 1)) / 2)
    call runtime_draw_text(footer_text, &
      footer_x, height - 42, 1, dim)
  end subroutine menu_render
end module menu_scene
