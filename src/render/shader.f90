module render_shader
  use, intrinsic :: iso_c_binding, only: c_int
  implicit none (type, external)
  private

  public :: shader_program

  type :: shader_program
    integer(c_int) :: program_id = 0_c_int
  contains
    procedure :: destroy => shader_program_destroy
    procedure :: is_valid => shader_program_is_valid
    procedure :: use_program => shader_program_use
  end type shader_program
contains
  subroutine shader_program_destroy(this)
    class(shader_program), intent(inout) :: this

    this%program_id = 0_c_int
  end subroutine shader_program_destroy

  logical function shader_program_is_valid(this) result(value)
    class(shader_program), intent(in) :: this

    value = this%program_id /= 0_c_int
  end function shader_program_is_valid

  subroutine shader_program_use(this)
    class(shader_program), intent(in) :: this

    if (.not. this%is_valid()) return
  end subroutine shader_program_use
end module render_shader
