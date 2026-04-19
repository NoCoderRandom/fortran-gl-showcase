module anim_keyframe_track
  use core_kinds, only: real64
  implicit none (type, external)
  private

  integer, parameter, public :: interp_linear = 1
  integer, parameter, public :: interp_cubic = 2
  integer, parameter, public :: interp_smoothstep = 3

  public :: interpolation_mode_from_name
  public :: keyframe_track

  type :: keyframe_track
    character(len=:), allocatable :: name
    integer :: interpolation = interp_linear
    real(real64), allocatable :: times(:)
    real(real64), allocatable :: values(:)
  contains
    procedure :: add_key => track_add_key
    procedure :: evaluate => track_evaluate
    procedure :: key_count => track_key_count
    procedure :: reset => track_reset
    procedure :: set_meta => track_set_meta
  end type keyframe_track

contains
  subroutine track_reset(this)
    class(keyframe_track), intent(inout) :: this

    if (allocated(this%name)) deallocate(this%name)
    if (allocated(this%times)) deallocate(this%times)
    if (allocated(this%values)) deallocate(this%values)
    this%interpolation = interp_linear
  end subroutine track_reset

  subroutine track_set_meta(this, track_name, interpolation)
    class(keyframe_track), intent(inout) :: this
    character(len=*), intent(in) :: track_name
    integer, intent(in), value :: interpolation

    this%name = trim(track_name)
    this%interpolation = interpolation
  end subroutine track_set_meta

  integer function track_key_count(this) result(count)
    class(keyframe_track), intent(in) :: this

    if (.not. allocated(this%times)) then
      count = 0
    else
      count = size(this%times)
    end if
  end function track_key_count

  subroutine track_add_key(this, time_value, sample_value)
    class(keyframe_track), intent(inout) :: this
    real(real64), intent(in), value :: time_value
    real(real64), intent(in), value :: sample_value
    real(real64), allocatable :: new_times(:)
    real(real64), allocatable :: new_values(:)
    integer :: count

    count = this%key_count()
    allocate(new_times(count + 1))
    allocate(new_values(count + 1))
    if (count > 0) then
      new_times(1:count) = this%times
      new_values(1:count) = this%values
    end if
    new_times(count + 1) = time_value
    new_values(count + 1) = sample_value
    call move_alloc(new_times, this%times)
    call move_alloc(new_values, this%values)
  end subroutine track_add_key

  real(real64) function track_evaluate(this, time_value) result(sample)
    class(keyframe_track), intent(in) :: this
    real(real64), intent(in), value :: time_value
    integer :: index
    real(real64) :: alpha

    if (this%key_count() <= 0) error stop "Track has no keys."
    if (this%key_count() == 1) then
      sample = this%values(1)
      return
    end if
    if (time_value <= this%times(1)) then
      sample = this%values(1)
      return
    end if
    if (time_value >= this%times(this%key_count())) then
      sample = this%values(this%key_count())
      return
    end if

    do index = 1, this%key_count() - 1
      if (time_value >= this%times(index) .and. time_value <= this%times(index + 1)) exit
    end do

    alpha = (time_value - this%times(index)) / max(1.0e-12_real64, this%times(index + 1) - this%times(index))
    select case (this%interpolation)
    case (interp_smoothstep)
      alpha = alpha * alpha * (3.0_real64 - 2.0_real64 * alpha)
      sample = lerp(this%values(index), this%values(index + 1), alpha)
    case (interp_cubic)
      sample = catmull_rom( &
        sample_value(this%values, index - 1), this%values(index), this%values(index + 1), &
        sample_value(this%values, index + 2), alpha &
      )
    case default
      sample = lerp(this%values(index), this%values(index + 1), alpha)
    end select
  end function track_evaluate

  integer function interpolation_mode_from_name(name) result(mode)
    character(len=*), intent(in) :: name

    select case (trim(name))
    case ("linear")
      mode = interp_linear
    case ("cubic")
      mode = interp_cubic
    case ("smoothstep")
      mode = interp_smoothstep
    case default
      error stop "Unknown interpolation mode."
    end select
  end function interpolation_mode_from_name

  real(real64) function sample_value(values, index) result(value)
    real(real64), intent(in) :: values(:)
    integer, intent(in), value :: index

    if (index < 1) then
      value = values(1)
    else if (index > size(values)) then
      value = values(size(values))
    else
      value = values(index)
    end if
  end function sample_value

  real(real64) function lerp(a, b, alpha) result(value)
    real(real64), intent(in), value :: a
    real(real64), intent(in), value :: b
    real(real64), intent(in), value :: alpha

    value = a + (b - a) * alpha
  end function lerp

  real(real64) function catmull_rom(p0, p1, p2, p3, alpha) result(value)
    real(real64), intent(in), value :: p0
    real(real64), intent(in), value :: p1
    real(real64), intent(in), value :: p2
    real(real64), intent(in), value :: p3
    real(real64), intent(in), value :: alpha
    real(real64) :: alpha2
    real(real64) :: alpha3

    alpha2 = alpha * alpha
    alpha3 = alpha2 * alpha
    value = 0.5_real64 * ( &
      2.0_real64 * p1 + (-p0 + p2) * alpha + &
      (2.0_real64 * p0 - 5.0_real64 * p1 + 4.0_real64 * p2 - p3) * alpha2 + &
      (-p0 + 3.0_real64 * p1 - 3.0_real64 * p2 + p3) * alpha3 &
    )
  end function catmull_rom
end module anim_keyframe_track
