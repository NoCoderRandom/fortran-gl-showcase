module coming_soon_scene
  use, intrinsic :: iso_c_binding, only: c_float
  use app_runtime, only: runtime_draw_text, runtime_framebuffer_size, runtime_measure_text
  use app_runtime, only: runtime_request_menu, runtime_was_pressed
  use core_kinds, only: real64
  use gl_loader, only: gl_clear, gl_clear_color, gl_color_buffer_bit
  use platform_input, only: key_escape
  use scene_base, only: scene_type
  implicit none (type, external)
  private

  public :: coming_soon_scene_type
  public :: setup_coming_soon_scene

  type, extends(scene_type) :: coming_soon_scene_type
    character(len=64) :: scene_name = ""
    character(len=96) :: display_name = ""
  contains
    procedure :: destroy => coming_soon_destroy
    procedure :: get_name => coming_soon_get_name
    procedure :: init => coming_soon_init
    procedure :: render => coming_soon_render
    procedure :: update => coming_soon_update
  end type coming_soon_scene_type
contains
  subroutine setup_coming_soon_scene(scene, scene_name, display_name)
    class(scene_type), allocatable, intent(out) :: scene
    character(len=*), intent(in) :: scene_name
    character(len=*), intent(in) :: display_name

    allocate(coming_soon_scene_type :: scene)
    select type (scene)
    type is (coming_soon_scene_type)
      scene%scene_name = ""
      scene%display_name = ""
      scene%scene_name(1:len_trim(scene_name)) = scene_name(1:len_trim(scene_name))
      scene%display_name(1:len_trim(display_name)) = display_name(1:len_trim(display_name))
    class default
      error stop "Unexpected scene allocation failure."
    end select
  end subroutine setup_coming_soon_scene

  subroutine coming_soon_destroy(this)
    class(coming_soon_scene_type), intent(inout) :: this

    if (.false.) print *, same_type_as(this, this)
  end subroutine coming_soon_destroy

  subroutine coming_soon_get_name(this, value)
    class(coming_soon_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    value = trim(this%scene_name)
  end subroutine coming_soon_get_name

  subroutine coming_soon_init(this)
    class(coming_soon_scene_type), intent(inout) :: this

    if (len_trim(this%display_name) == 0) error stop "Coming soon scene has no display name."
  end subroutine coming_soon_init

  subroutine coming_soon_update(this, delta_seconds)
    class(coming_soon_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds

    if (.false.) print *, same_type_as(this, this)
    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
    if (runtime_was_pressed(key_escape)) call runtime_request_menu()
  end subroutine coming_soon_update

  subroutine coming_soon_render(this)
    class(coming_soon_scene_type), intent(inout) :: this
    integer :: width
    integer :: height
    integer :: title_x
    integer :: subtitle_x
    real(c_float) :: title_color(4)
    real(c_float) :: subtitle_color(4)

    call runtime_framebuffer_size(width, height)
    call gl_clear_color(0.06_c_float, 0.07_c_float, 0.09_c_float, 1.0_c_float)
    call gl_clear(gl_color_buffer_bit)

    title_color = [0.95_c_float, 0.88_c_float, 0.56_c_float, 1.0_c_float]
    subtitle_color = [0.76_c_float, 0.79_c_float, 0.86_c_float, 1.0_c_float]

    title_x = max(32, (width - runtime_measure_text(trim(this%display_name), 4)) / 2)
    subtitle_x = max(32, (width - runtime_measure_text("COMING SOON", 2)) / 2)
    call runtime_draw_text(trim(this%display_name), title_x, height / 3, 4, title_color)
    call runtime_draw_text("COMING SOON", subtitle_x, height / 3 + 72, 2, subtitle_color)
    call runtime_draw_text("ESC RETURNS TO THE MENU", max(32, (width - runtime_measure_text("ESC RETURNS TO THE MENU", 1)) / 2), &
      height / 3 + 132, 1, subtitle_color)
  end subroutine coming_soon_render
end module coming_soon_scene
