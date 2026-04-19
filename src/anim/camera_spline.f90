module anim_camera_spline
  use core_kinds, only: real64
  use anim_timeline, only: timeline_type
  implicit none (type, external)
  private

  public :: camera_spline

  type :: camera_spline
    character(len=:), allocatable :: look_prefix
    character(len=:), allocatable :: position_prefix
  contains
    procedure :: configure => camera_spline_configure
    procedure :: evaluate => camera_spline_evaluate
  end type camera_spline

contains
  subroutine camera_spline_configure(this, position_prefix, look_prefix)
    class(camera_spline), intent(inout) :: this
    character(len=*), intent(in) :: position_prefix
    character(len=*), intent(in) :: look_prefix

    this%position_prefix = trim(position_prefix)
    this%look_prefix = trim(look_prefix)
  end subroutine camera_spline_configure

  subroutine camera_spline_evaluate(this, timeline, time_value, position, look_at)
    class(camera_spline), intent(in) :: this
    type(timeline_type), intent(in) :: timeline
    real(real64), intent(in), value :: time_value
    real(real64), intent(out) :: position(3)
    real(real64), intent(out) :: look_at(3)

    position(1) = timeline%get_value(trim(this%position_prefix)//"_x", time_value, 0.0_real64)
    position(2) = timeline%get_value(trim(this%position_prefix)//"_y", time_value, 0.0_real64)
    position(3) = timeline%get_value(trim(this%position_prefix)//"_z", time_value, 0.0_real64)
    look_at(1) = timeline%get_value(trim(this%look_prefix)//"_x", time_value, 0.0_real64)
    look_at(2) = timeline%get_value(trim(this%look_prefix)//"_y", time_value, 0.0_real64)
    look_at(3) = timeline%get_value(trim(this%look_prefix)//"_z", time_value, 0.0_real64)
  end subroutine camera_spline_evaluate
end module anim_camera_spline
