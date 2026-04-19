module gl_loader
  use, intrinsic :: iso_c_binding, only: c_associated, c_char, c_float, c_int, c_ptr
  use platform_window, only: glfw_window
  implicit none (type, external)
  private

  integer(c_int), parameter, public :: gl_array_buffer = int(z'8892', c_int)
  integer(c_int), parameter, public :: gl_blend = int(z'0BE2', c_int)
  integer(c_int), parameter, public :: gl_clamp_to_edge = int(z'812F', c_int)
  integer(c_int), parameter, public :: gl_color_buffer_bit = int(z'00004000', c_int)
  integer(c_int), parameter, public :: gl_compile_status = int(z'8B81', c_int)
  integer(c_int), parameter, public :: gl_dynamic_draw = int(z'88E8', c_int)
  integer(c_int), parameter, public :: gl_false = 0_c_int
  integer(c_int), parameter, public :: gl_float = int(z'1406', c_int)
  integer(c_int), parameter, public :: gl_fragment_shader = int(z'8B30', c_int)
  integer(c_int), parameter, public :: gl_info_log_length = int(z'8B84', c_int)
  integer(c_int), parameter, public :: gl_link_status = int(z'8B82', c_int)
  integer(c_int), parameter, public :: gl_linear = int(z'2601', c_int)
  integer(c_int), parameter, public :: gl_nearest = int(z'2600', c_int)
  integer(c_int), parameter, public :: gl_one_minus_src_alpha = int(z'0303', c_int)
  integer(c_int), parameter, public :: gl_red = int(z'1903', c_int)
  integer(c_int), parameter, public :: gl_r8 = int(z'8229', c_int)
  integer(c_int), parameter, public :: gl_src_alpha = int(z'0302', c_int)
  integer(c_int), parameter, public :: gl_static_draw = int(z'88E4', c_int)
  integer(c_int), parameter, public :: gl_texture0 = int(z'84C0', c_int)
  integer(c_int), parameter, public :: gl_texture_2d = int(z'0DE1', c_int)
  integer(c_int), parameter, public :: gl_texture_mag_filter = int(z'2800', c_int)
  integer(c_int), parameter, public :: gl_texture_min_filter = int(z'2801', c_int)
  integer(c_int), parameter, public :: gl_texture_wrap_s = int(z'2802', c_int)
  integer(c_int), parameter, public :: gl_texture_wrap_t = int(z'2803', c_int)
  integer(c_int), parameter, public :: gl_triangles = int(z'0004', c_int)
  integer(c_int), parameter, public :: gl_true = 1_c_int
  integer(c_int), parameter, public :: gl_unsigned_byte = int(z'1401', c_int)
  integer(c_int), parameter, public :: gl_vertex_shader = int(z'8B31', c_int)

  public :: gl_active_texture
  public :: gl_attach_shader
  public :: gl_bind_buffer
  public :: gl_bind_texture
  public :: gl_bind_vertex_array
  public :: gl_blend_func
  public :: gl_buffer_data
  public :: gl_buffer_sub_data
  public :: gl_clear
  public :: gl_clear_color
  public :: gl_compile_shader
  public :: gl_create_program
  public :: gl_create_shader
  public :: gl_delete_buffers
  public :: gl_delete_program
  public :: gl_delete_shader
  public :: gl_delete_textures
  public :: gl_delete_vertex_arrays
  public :: gl_draw_arrays
  public :: gl_enable
  public :: gl_enable_vertex_attrib_array
  public :: gl_gen_buffers
  public :: gl_gen_textures
  public :: gl_gen_vertex_arrays
  public :: gl_get_program_info_log
  public :: gl_get_program_iv
  public :: gl_get_shader_info_log
  public :: gl_get_shader_iv
  public :: gl_get_uniform_location
  public :: gl_link_program
  public :: gl_load
  public :: gl_shader_source
  public :: gl_tex_image_2d
  public :: gl_tex_parameteri
  public :: gl_uniform1f
  public :: gl_uniform1i
  public :: gl_uniform2f
  public :: gl_uniform4f
  public :: gl_use_program
  public :: gl_vertex_attrib_pointer
  public :: gl_viewport

  interface
    subroutine gl_active_texture(texture) bind(C, name="glActiveTexture")
      import :: c_int
      integer(c_int), value :: texture
    end subroutine gl_active_texture

    subroutine gl_attach_shader(program, shader) bind(C, name="glAttachShader")
      import :: c_int
      integer(c_int), value :: program
      integer(c_int), value :: shader
    end subroutine gl_attach_shader

    subroutine gl_bind_buffer(target, buffer) bind(C, name="glBindBuffer")
      import :: c_int
      integer(c_int), value :: target
      integer(c_int), value :: buffer
    end subroutine gl_bind_buffer

    subroutine gl_bind_texture(target, texture) bind(C, name="glBindTexture")
      import :: c_int
      integer(c_int), value :: target
      integer(c_int), value :: texture
    end subroutine gl_bind_texture

    subroutine gl_bind_vertex_array(array) bind(C, name="glBindVertexArray")
      import :: c_int
      integer(c_int), value :: array
    end subroutine gl_bind_vertex_array

    subroutine gl_blend_func(sfactor, dfactor) bind(C, name="glBlendFunc")
      import :: c_int
      integer(c_int), value :: sfactor
      integer(c_int), value :: dfactor
    end subroutine gl_blend_func

    subroutine gl_buffer_data(target, size_bytes, data, usage) bind(C, name="glBufferData")
      import :: c_int, c_ptr
      integer(c_int), value :: target
      integer(c_int), value :: size_bytes
      type(c_ptr), value :: data
      integer(c_int), value :: usage
    end subroutine gl_buffer_data

    subroutine gl_buffer_sub_data(target, offset_bytes, size_bytes, data) bind(C, name="glBufferSubData")
      import :: c_int, c_ptr
      integer(c_int), value :: target
      integer(c_int), value :: offset_bytes
      integer(c_int), value :: size_bytes
      type(c_ptr), value :: data
    end subroutine gl_buffer_sub_data

    subroutine gl_clear(mask) bind(C, name="glClear")
      import :: c_int
      integer(c_int), value :: mask
    end subroutine gl_clear

    subroutine gl_clear_color(red, green, blue, alpha) bind(C, name="glClearColor")
      import :: c_float
      real(c_float), value :: red
      real(c_float), value :: green
      real(c_float), value :: blue
      real(c_float), value :: alpha
    end subroutine gl_clear_color

    subroutine gl_compile_shader(shader) bind(C, name="glCompileShader")
      import :: c_int
      integer(c_int), value :: shader
    end subroutine gl_compile_shader

    integer(c_int) function gl_create_program() bind(C, name="glCreateProgram")
      import :: c_int
    end function gl_create_program

    integer(c_int) function gl_create_shader(shader_type) bind(C, name="glCreateShader")
      import :: c_int
      integer(c_int), value :: shader_type
    end function gl_create_shader

    subroutine gl_delete_buffers(count, buffers) bind(C, name="glDeleteBuffers")
      import :: c_int, c_ptr
      integer(c_int), value :: count
      type(c_ptr), value :: buffers
    end subroutine gl_delete_buffers

    subroutine gl_delete_program(program) bind(C, name="glDeleteProgram")
      import :: c_int
      integer(c_int), value :: program
    end subroutine gl_delete_program

    subroutine gl_delete_shader(shader) bind(C, name="glDeleteShader")
      import :: c_int
      integer(c_int), value :: shader
    end subroutine gl_delete_shader

    subroutine gl_delete_textures(count, textures) bind(C, name="glDeleteTextures")
      import :: c_int, c_ptr
      integer(c_int), value :: count
      type(c_ptr), value :: textures
    end subroutine gl_delete_textures

    subroutine gl_delete_vertex_arrays(count, arrays) bind(C, name="glDeleteVertexArrays")
      import :: c_int, c_ptr
      integer(c_int), value :: count
      type(c_ptr), value :: arrays
    end subroutine gl_delete_vertex_arrays

    subroutine gl_draw_arrays(mode, first, count) bind(C, name="glDrawArrays")
      import :: c_int
      integer(c_int), value :: mode
      integer(c_int), value :: first
      integer(c_int), value :: count
    end subroutine gl_draw_arrays

    subroutine gl_enable(cap) bind(C, name="glEnable")
      import :: c_int
      integer(c_int), value :: cap
    end subroutine gl_enable

    subroutine gl_enable_vertex_attrib_array(index) bind(C, name="glEnableVertexAttribArray")
      import :: c_int
      integer(c_int), value :: index
    end subroutine gl_enable_vertex_attrib_array

    subroutine gl_gen_buffers(count, buffers) bind(C, name="glGenBuffers")
      import :: c_int, c_ptr
      integer(c_int), value :: count
      type(c_ptr), value :: buffers
    end subroutine gl_gen_buffers

    subroutine gl_gen_textures(count, textures) bind(C, name="glGenTextures")
      import :: c_int, c_ptr
      integer(c_int), value :: count
      type(c_ptr), value :: textures
    end subroutine gl_gen_textures

    subroutine gl_gen_vertex_arrays(count, arrays) bind(C, name="glGenVertexArrays")
      import :: c_int, c_ptr
      integer(c_int), value :: count
      type(c_ptr), value :: arrays
    end subroutine gl_gen_vertex_arrays

    subroutine gl_get_program_info_log(program, max_length, length_written, info_log) bind(C, name="glGetProgramInfoLog")
      import :: c_char, c_int, c_ptr
      integer(c_int), value :: program
      integer(c_int), value :: max_length
      type(c_ptr), value :: length_written
      character(kind=c_char), intent(out) :: info_log(*)
    end subroutine gl_get_program_info_log

    subroutine gl_get_program_iv(program, pname, params) bind(C, name="glGetProgramiv")
      import :: c_int, c_ptr
      integer(c_int), value :: program
      integer(c_int), value :: pname
      type(c_ptr), value :: params
    end subroutine gl_get_program_iv

    subroutine gl_get_shader_info_log(shader, max_length, length_written, info_log) bind(C, name="glGetShaderInfoLog")
      import :: c_char, c_int, c_ptr
      integer(c_int), value :: shader
      integer(c_int), value :: max_length
      type(c_ptr), value :: length_written
      character(kind=c_char), intent(out) :: info_log(*)
    end subroutine gl_get_shader_info_log

    subroutine gl_get_shader_iv(shader, pname, params) bind(C, name="glGetShaderiv")
      import :: c_int, c_ptr
      integer(c_int), value :: shader
      integer(c_int), value :: pname
      type(c_ptr), value :: params
    end subroutine gl_get_shader_iv

    integer(c_int) function gl_get_uniform_location(program, name) bind(C, name="glGetUniformLocation")
      import :: c_char, c_int
      integer(c_int), value :: program
      character(kind=c_char), intent(in) :: name(*)
    end function gl_get_uniform_location

    subroutine gl_link_program(program) bind(C, name="glLinkProgram")
      import :: c_int
      integer(c_int), value :: program
    end subroutine gl_link_program

    subroutine gl_shader_source(shader, count, strings, lengths) bind(C, name="glShaderSource")
      import :: c_int, c_ptr
      integer(c_int), value :: shader
      integer(c_int), value :: count
      type(c_ptr), value :: strings
      type(c_ptr), value :: lengths
    end subroutine gl_shader_source

    subroutine gl_tex_image_2d(target, level, internal_format, width, height, border, format, data_type, pixels) &
      bind(C, name="glTexImage2D")
      import :: c_int, c_ptr
      integer(c_int), value :: target
      integer(c_int), value :: level
      integer(c_int), value :: internal_format
      integer(c_int), value :: width
      integer(c_int), value :: height
      integer(c_int), value :: border
      integer(c_int), value :: format
      integer(c_int), value :: data_type
      type(c_ptr), value :: pixels
    end subroutine gl_tex_image_2d

    subroutine gl_tex_parameteri(target, pname, value) bind(C, name="glTexParameteri")
      import :: c_int
      integer(c_int), value :: target
      integer(c_int), value :: pname
      integer(c_int), value :: value
    end subroutine gl_tex_parameteri

    subroutine gl_uniform1f(location, value) bind(C, name="glUniform1f")
      import :: c_float, c_int
      integer(c_int), value :: location
      real(c_float), value :: value
    end subroutine gl_uniform1f

    subroutine gl_uniform1i(location, value) bind(C, name="glUniform1i")
      import :: c_int
      integer(c_int), value :: location
      integer(c_int), value :: value
    end subroutine gl_uniform1i

    subroutine gl_uniform2f(location, x, y) bind(C, name="glUniform2f")
      import :: c_float, c_int
      integer(c_int), value :: location
      real(c_float), value :: x
      real(c_float), value :: y
    end subroutine gl_uniform2f

    subroutine gl_uniform4f(location, x, y, z, w) bind(C, name="glUniform4f")
      import :: c_float, c_int
      integer(c_int), value :: location
      real(c_float), value :: x
      real(c_float), value :: y
      real(c_float), value :: z
      real(c_float), value :: w
    end subroutine gl_uniform4f

    subroutine gl_use_program(program) bind(C, name="glUseProgram")
      import :: c_int
      integer(c_int), value :: program
    end subroutine gl_use_program

    subroutine gl_vertex_attrib_pointer(index, size, data_type, normalized, stride_bytes, pointer) &
      bind(C, name="glVertexAttribPointer")
      import :: c_int, c_ptr
      integer(c_int), value :: index
      integer(c_int), value :: size
      integer(c_int), value :: data_type
      integer(c_int), value :: normalized
      integer(c_int), value :: stride_bytes
      type(c_ptr), value :: pointer
    end subroutine gl_vertex_attrib_pointer

    subroutine gl_viewport(x, y, width, height) bind(C, name="glViewport")
      import :: c_int
      integer(c_int), value :: x
      integer(c_int), value :: y
      integer(c_int), value :: width
      integer(c_int), value :: height
    end subroutine gl_viewport
  end interface
contains
  subroutine gl_load(window)
    class(glfw_window), intent(inout) :: window
    type(c_ptr) :: handle

    handle = window%get_native_handle()
    if (.not. c_associated(handle)) error stop "OpenGL context handle missing."
  end subroutine gl_load
end module gl_loader
