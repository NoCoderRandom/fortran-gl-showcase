module render_shader
  use, intrinsic :: iso_c_binding, only: c_char, c_int, c_loc, c_null_char, c_null_ptr, c_ptr
  use core_logger, only: log_error
  use gl_loader, only: gl_attach_shader, gl_compile_shader, gl_compile_status, gl_create_program
  use gl_loader, only: gl_compute_shader
  use gl_loader, only: gl_create_shader, gl_delete_program, gl_delete_shader, gl_fragment_shader
  use gl_loader, only: gl_get_program_info_log, gl_get_program_iv, gl_get_shader_info_log, gl_get_shader_iv
  use gl_loader, only: gl_get_uniform_location, gl_info_log_length, gl_link_program, gl_link_status
  use gl_loader, only: gl_shader_source, gl_true, gl_use_program, gl_vertex_shader
  implicit none (type, external)
  private

  public :: shader_program

  type :: shader_program
    integer(c_int) :: program_id = 0_c_int
  contains
    procedure :: build => shader_program_build
    procedure :: build_compute => shader_program_build_compute
    procedure :: destroy => shader_program_destroy
    procedure :: is_valid => shader_program_is_valid
    procedure :: uniform => shader_program_uniform
    procedure :: use_program => shader_program_use
  end type shader_program
contains
  subroutine shader_program_build(this, vertex_source, fragment_source, label)
    class(shader_program), intent(inout) :: this
    character(len=*), intent(in) :: vertex_source
    character(len=*), intent(in) :: fragment_source
    character(len=*), intent(in) :: label
    integer(c_int) :: fragment_shader_id
    integer(c_int), target :: link_ok
    integer(c_int) :: vertex_shader_id

    call this%destroy()
    vertex_shader_id = compile_stage(gl_vertex_shader, vertex_source, trim(label)//" vertex")
    fragment_shader_id = compile_stage(gl_fragment_shader, fragment_source, trim(label)//" fragment")

    this%program_id = gl_create_program()
    if (this%program_id == 0_c_int) error stop "Program creation failed."
    call gl_attach_shader(this%program_id, vertex_shader_id)
    call gl_attach_shader(this%program_id, fragment_shader_id)
    call gl_link_program(this%program_id)
    call gl_get_program_iv(this%program_id, gl_link_status, c_loc(link_ok))
    if (link_ok /= gl_true) then
      call log_error(trim(label)//": "//trim(fetch_program_log(this%program_id)))
      error stop "Program link failed."
    end if

    call gl_delete_shader(vertex_shader_id)
    call gl_delete_shader(fragment_shader_id)
  end subroutine shader_program_build

  subroutine shader_program_build_compute(this, compute_source, label)
    class(shader_program), intent(inout) :: this
    character(len=*), intent(in) :: compute_source
    character(len=*), intent(in) :: label
    integer(c_int) :: compute_shader_id
    integer(c_int), target :: link_ok

    call this%destroy()
    compute_shader_id = compile_stage(gl_compute_shader, compute_source, trim(label)//" compute")

    this%program_id = gl_create_program()
    if (this%program_id == 0_c_int) error stop "Program creation failed."
    call gl_attach_shader(this%program_id, compute_shader_id)
    call gl_link_program(this%program_id)
    call gl_get_program_iv(this%program_id, gl_link_status, c_loc(link_ok))
    if (link_ok /= gl_true) then
      call log_error(trim(label)//": "//trim(fetch_program_log(this%program_id)))
      error stop "Program link failed."
    end if

    call gl_delete_shader(compute_shader_id)
  end subroutine shader_program_build_compute

  subroutine shader_program_destroy(this)
    class(shader_program), intent(inout) :: this

    if (this%program_id /= 0_c_int) call gl_delete_program(this%program_id)
    this%program_id = 0_c_int
  end subroutine shader_program_destroy

  logical function shader_program_is_valid(this) result(value)
    class(shader_program), intent(in) :: this

    value = this%program_id /= 0_c_int
  end function shader_program_is_valid

  integer(c_int) function shader_program_uniform(this, name) result(location)
    class(shader_program), intent(in) :: this
    character(len=*), intent(in) :: name
    character(kind=c_char, len=:), allocatable :: c_name

    c_name = trim(name)//c_null_char
    location = gl_get_uniform_location(this%program_id, c_name)
  end function shader_program_uniform

  subroutine shader_program_use(this)
    class(shader_program), intent(in) :: this

    if (this%program_id == 0_c_int) error stop "Attempted to use an invalid shader program."
    call gl_use_program(this%program_id)
  end subroutine shader_program_use

  integer(c_int) function compile_stage(shader_type, source, label) result(shader_id)
    integer(c_int), intent(in), value :: shader_type
    character(len=*), intent(in) :: source
    character(len=*), intent(in) :: label
    integer(c_int), target :: compile_ok
    integer(c_int), target :: lengths(1)
    character(kind=c_char, len=:), allocatable, target :: c_source
    type(c_ptr), target :: source_ptrs(1)

    shader_id = gl_create_shader(shader_type)
    if (shader_id == 0_c_int) error stop "Shader creation failed."

    c_source = source//c_null_char
    source_ptrs(1) = c_loc(c_source)
    lengths(1) = len_trim(source)
    call gl_shader_source(shader_id, 1_c_int, c_loc(source_ptrs), c_loc(lengths))
    call gl_compile_shader(shader_id)
    call gl_get_shader_iv(shader_id, gl_compile_status, c_loc(compile_ok))
    if (compile_ok /= gl_true) then
      call log_error(trim(label)//": "//trim(fetch_shader_log(shader_id)))
      error stop "Shader compilation failed."
    end if
  end function compile_stage

  function fetch_program_log(program_id) result(message)
    integer(c_int), intent(in), value :: program_id
    character(len=:), allocatable :: message

    message = fetch_log(program_id, .true.)
  end function fetch_program_log

  function fetch_shader_log(shader_id) result(message)
    integer(c_int), intent(in), value :: shader_id
    character(len=:), allocatable :: message

    message = fetch_log(shader_id, .false.)
  end function fetch_shader_log

  function fetch_log(object_id, is_program) result(message)
    integer(c_int), intent(in), value :: object_id
    logical, intent(in), value :: is_program
    character(len=:), allocatable :: message
    integer(c_int), target :: log_length
    integer(c_int), target :: written
    character(kind=c_char), allocatable, target :: buffer(:)
    integer :: i

    if (is_program) then
      call gl_get_program_iv(object_id, gl_info_log_length, c_loc(log_length))
    else
      call gl_get_shader_iv(object_id, gl_info_log_length, c_loc(log_length))
    end if

    if (log_length <= 1_c_int) then
      message = "no OpenGL log available"
      return
    end if

    allocate(buffer(log_length))
    if (is_program) then
      call gl_get_program_info_log(object_id, log_length, c_loc(written), buffer)
    else
      call gl_get_shader_info_log(object_id, log_length, c_loc(written), buffer)
    end if

    allocate(character(len=max(0, written - 1)) :: message)
    do i = 1, len(message)
      message(i:i) = buffer(i)
    end do
  end function fetch_log
end module render_shader
