module anim_tiny_parser
  use core_kinds, only: real64
  use core_text_file, only: read_text_file
  use anim_keyframe_track, only: interpolation_mode_from_name
  use anim_timeline, only: timeline_type
  implicit none (type, external)
  private

  public :: load_timeline_file

contains
  subroutine load_timeline_file(path, timeline)
    character(len=*), intent(in) :: path
    type(timeline_type), intent(inout) :: timeline
    character(len=:), allocatable :: content
    character(len=:), allocatable :: current_track
    character(len=:), allocatable :: line
    character(len=64) :: mode_name
    character(len=128) :: track_name
    integer :: cursor
    integer :: line_number
    integer :: next_break
    logical :: inside_track
    real(real64) :: duration
    real(real64) :: time_value
    real(real64) :: sample_value

    call timeline%reset()
    content = read_text_file(path)
    cursor = 1
    line_number = 0
    inside_track = .false.

    do while (cursor <= len(content))
      next_break = index(content(cursor:), new_line("a"))
      if (next_break == 0) then
        line = content(cursor:)
        cursor = len(content) + 1
      else
        line = content(cursor:cursor + next_break - 2)
        cursor = cursor + next_break
      end if
      line_number = line_number + 1
      call strip_comment(line)
      line = adjustl(trim(line))
      if (len_trim(line) == 0) cycle

      if (starts_with(line, "duration")) then
        read (line, *, err=900) track_name, duration
        call timeline%set_duration(duration)
        inside_track = .false.
        cycle
      end if

      if (starts_with(line, "track")) then
        read (line, *, err=900) mode_name, track_name, mode_name
        call timeline%start_track(trim(track_name), interpolation_mode_from_name(trim(mode_name)))
        current_track = trim(track_name)
        inside_track = .true.
        cycle
      end if

      if (.not. inside_track) call parse_error(line_number, "Expected 'duration' or 'track'.")
      read (line, *, err=900) time_value, sample_value
      call timeline%add_key(current_track, time_value, sample_value)
      cycle

900   call parse_error(line_number, "Malformed timeline line.")
    end do

    if (timeline%get_duration() <= 0.0_real64) call parse_error(line_number, "Timeline duration missing or invalid.")
  end subroutine load_timeline_file

  subroutine strip_comment(line)
    character(len=:), allocatable, intent(inout) :: line
    integer :: marker

    marker = index(line, "#")
    if (marker > 0) line = line(:marker - 1)
  end subroutine strip_comment

  logical function starts_with(line, prefix) result(matches)
    character(len=*), intent(in) :: line
    character(len=*), intent(in) :: prefix

    matches = len_trim(line) >= len_trim(prefix) .and. line(:len_trim(prefix)) == trim(prefix)
  end function starts_with

  subroutine parse_error(line_number, message)
    integer, intent(in), value :: line_number
    character(len=*), intent(in) :: message
    character(len=64) :: label

    write (label, '(a,i0,a)') "Timeline parse error on line ", line_number, "."
    error stop trim(label)//" "//trim(message)
  end subroutine parse_error
end module anim_tiny_parser
