module core_timing
  use core_kinds, only: int64, real64
  implicit none (type, external)
  private

  public :: frame_clock

  type :: frame_clock
    integer(int64) :: last_tick = 0_int64
    integer(int64) :: tick_rate = 0_int64
    real(real64) :: delta_seconds = 0.0_real64
  contains
    procedure :: reset => frame_clock_reset
    procedure :: step => frame_clock_step
  end type frame_clock
contains
  subroutine frame_clock_reset(this)
    class(frame_clock), intent(inout) :: this
    integer :: count
    integer :: count_rate

    call system_clock(count, count_rate)
    this%last_tick = int(count, int64)
    this%tick_rate = int(max(count_rate, 1), int64)
    this%delta_seconds = 0.0_real64
  end subroutine frame_clock_reset

  subroutine frame_clock_step(this)
    class(frame_clock), intent(inout) :: this
    integer :: count
    integer :: count_rate

    call system_clock(count, count_rate)
    if (this%tick_rate <= 0_int64) this%tick_rate = int(max(count_rate, 1), int64)
    this%delta_seconds = real(int(count, int64) - this%last_tick, real64) / real(this%tick_rate, real64)
    this%last_tick = int(count, int64)
  end subroutine frame_clock_step
end module core_timing

