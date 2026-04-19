module empty_scene
  use, intrinsic :: iso_c_binding, only: c_float
  use core_kinds, only: real64
  use gl_loader, only: gl_clear, gl_clear_color, gl_color_buffer_bit
  use scene_base, only: scene_type
  implicit none (type, external)
  private

  public :: empty_scene_type

  type, extends(scene_type) :: empty_scene_type
  contains
    procedure :: get_name => empty_scene_get_name
    procedure :: init => empty_scene_init
    procedure :: render => empty_scene_render
    procedure :: update => empty_scene_update
  end type empty_scene_type
contains
  subroutine empty_scene_get_name(this, value)
    class(empty_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "empty_scene"
  end subroutine empty_scene_get_name

  subroutine empty_scene_init(this)
    class(empty_scene_type), intent(inout) :: this
    character(len=32) :: name

    call this%get_name(name)
    if (len_trim(name) == 0) error stop "Empty scene name missing."
  end subroutine empty_scene_init

  subroutine empty_scene_render(this)
    class(empty_scene_type), intent(inout) :: this

    if (.false.) print *, same_type_as(this, this)
    call gl_clear_color(0.08_c_float, 0.08_c_float, 0.09_c_float, 1.0_c_float)
    call gl_clear(gl_color_buffer_bit)
  end subroutine empty_scene_render

  subroutine empty_scene_update(this, delta_seconds)
    class(empty_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds

    if (.false.) print *, same_type_as(this, this)
    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
  end subroutine empty_scene_update
end module empty_scene
