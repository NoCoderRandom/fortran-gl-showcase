module anim_timeline
  use core_kinds, only: real64
  use anim_keyframe_track, only: keyframe_track
  implicit none (type, external)
  private

  public :: timeline_type

  type :: timeline_type
    real(real64) :: duration = 0.0_real64
    type(keyframe_track), allocatable :: tracks(:)
  contains
    procedure :: add_key => timeline_add_key
    procedure :: get_duration => timeline_get_duration
    procedure :: get_track_count => timeline_get_track_count
    procedure :: get_track_name => timeline_get_track_name
    procedure :: get_value => timeline_get_value
    procedure :: reset => timeline_reset
    procedure :: set_duration => timeline_set_duration
    procedure :: start_track => timeline_start_track
  end type timeline_type

contains
  subroutine timeline_reset(this)
    class(timeline_type), intent(inout) :: this

    if (allocated(this%tracks)) deallocate(this%tracks)
    this%duration = 0.0_real64
  end subroutine timeline_reset

  subroutine timeline_set_duration(this, duration)
    class(timeline_type), intent(inout) :: this
    real(real64), intent(in), value :: duration

    this%duration = duration
  end subroutine timeline_set_duration

  real(real64) function timeline_get_duration(this) result(duration)
    class(timeline_type), intent(in) :: this

    duration = this%duration
  end function timeline_get_duration

  integer function timeline_get_track_count(this) result(count)
    class(timeline_type), intent(in) :: this

    if (allocated(this%tracks)) then
      count = size(this%tracks)
    else
      count = 0
    end if
  end function timeline_get_track_count

  subroutine timeline_get_track_name(this, index, name)
    class(timeline_type), intent(in) :: this
    integer, intent(in), value :: index
    character(len=*), intent(out) :: name

    if (index < 1 .or. index > this%get_track_count()) error stop "Timeline track index out of range."
    name = this%tracks(index)%name
  end subroutine timeline_get_track_name

  subroutine timeline_start_track(this, track_name, interpolation)
    class(timeline_type), intent(inout) :: this
    character(len=*), intent(in) :: track_name
    integer, intent(in), value :: interpolation
    type(keyframe_track), allocatable :: new_tracks(:)
    integer :: count
    integer :: index

    do index = 1, this%get_track_count()
      if (trim(this%tracks(index)%name) == trim(track_name)) then
        call this%tracks(index)%reset()
        call this%tracks(index)%set_meta(track_name, interpolation)
        return
      end if
    end do

    count = this%get_track_count()
    allocate(new_tracks(count + 1))
    if (count > 0) new_tracks(1:count) = this%tracks
    call new_tracks(count + 1)%set_meta(track_name, interpolation)
    call move_alloc(new_tracks, this%tracks)
  end subroutine timeline_start_track

  subroutine timeline_add_key(this, track_name, time_value, sample_value)
    class(timeline_type), intent(inout) :: this
    character(len=*), intent(in) :: track_name
    real(real64), intent(in), value :: time_value
    real(real64), intent(in), value :: sample_value
    integer :: index

    do index = 1, this%get_track_count()
      if (trim(this%tracks(index)%name) == trim(track_name)) then
        call this%tracks(index)%add_key(time_value, sample_value)
        return
      end if
    end do

    error stop "Timeline key added to unknown track."
  end subroutine timeline_add_key

  real(real64) function timeline_get_value(this, track_name, time_value, fallback) result(value)
    class(timeline_type), intent(in) :: this
    character(len=*), intent(in) :: track_name
    real(real64), intent(in), value :: time_value
    real(real64), intent(in), value :: fallback
    integer :: index

    value = fallback
    do index = 1, this%get_track_count()
      if (trim(this%tracks(index)%name) == trim(track_name)) then
        value = this%tracks(index)%evaluate(time_value)
        return
      end if
    end do
  end function timeline_get_value
end module anim_timeline
