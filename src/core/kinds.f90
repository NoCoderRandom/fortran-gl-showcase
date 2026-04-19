module core_kinds
  use, intrinsic :: iso_c_binding, only: c_float, c_double, c_int32_t, c_int64_t
  implicit none (type, external)
  private

  integer, parameter, public :: real32 = c_float
  integer, parameter, public :: real64 = c_double
  integer, parameter, public :: int32 = c_int32_t
  integer, parameter, public :: int64 = c_int64_t
end module core_kinds

