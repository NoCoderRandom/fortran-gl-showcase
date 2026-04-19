module render_text_renderer
  use, intrinsic :: iso_c_binding, only: c_float, c_int, c_int8_t, c_intptr_t, c_loc, c_null_ptr, c_ptr
  use gl_loader, only: gl_active_texture, gl_array_buffer, gl_bind_buffer, gl_bind_texture
  use gl_loader, only: gl_bind_vertex_array, gl_blend, gl_blend_func, gl_buffer_data
  use gl_loader, only: gl_buffer_sub_data, gl_clamp_to_edge, gl_delete_buffers, gl_delete_textures
  use gl_loader, only: gl_delete_vertex_arrays, gl_draw_arrays, gl_dynamic_draw, gl_enable
  use gl_loader, only: gl_enable_vertex_attrib_array, gl_false, gl_float, gl_gen_buffers
  use gl_loader, only: gl_gen_textures, gl_gen_vertex_arrays, gl_nearest, gl_one_minus_src_alpha
  use gl_loader, only: gl_r8, gl_red, gl_src_alpha, gl_tex_image_2d, gl_tex_parameteri
  use gl_loader, only: gl_texture0, gl_texture_2d, gl_texture_mag_filter, gl_texture_min_filter
  use gl_loader, only: gl_texture_wrap_s, gl_texture_wrap_t, gl_triangles, gl_uniform1i
  use gl_loader, only: gl_uniform2f, gl_uniform4f, gl_unsigned_byte, gl_vertex_attrib_pointer
  use render_font_data, only: font_count, font_height, font_rows, font_width
  use render_shader, only: shader_program
  implicit none (type, external)
  private

  integer, parameter :: glyphs_per_row = 16
  integer, parameter :: atlas_width = glyphs_per_row * font_width
  integer, parameter :: atlas_height = 8 * font_height

  public :: text_renderer

  type :: text_renderer
    type(shader_program) :: program
    integer(c_int) :: texture_id = 0_c_int
    integer(c_int) :: vao = 0_c_int
    integer(c_int) :: vbo = 0_c_int
    integer(c_int) :: color_uniform = -1
    integer(c_int) :: screen_uniform = -1
    integer(c_int) :: texture_uniform = -1
  contains
    procedure :: begin_frame => text_begin_frame
    procedure :: destroy => text_destroy
    procedure :: draw => text_draw
    procedure :: initialize => text_initialize
    procedure :: measure => text_measure
  end type text_renderer

  character(len=*), parameter :: text_vertex_shader = &
    "#version 330 core"//new_line("a")// &
    "layout(location = 0) in vec2 a_position;"//new_line("a")// &
    "layout(location = 1) in vec2 a_uv;"//new_line("a")// &
    "uniform vec2 u_screen;"//new_line("a")// &
    "out vec2 v_uv;"//new_line("a")// &
    "void main() {"//new_line("a")// &
    "  vec2 clip = vec2((a_position.x / u_screen.x) * 2.0 - 1.0, 1.0 - (a_position.y / u_screen.y) * 2.0);"//new_line("a")// &
    "  v_uv = a_uv;"//new_line("a")// &
    "  gl_Position = vec4(clip, 0.0, 1.0);"//new_line("a")// &
    "}"

  character(len=*), parameter :: text_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec2 v_uv;"//new_line("a")// &
    "out vec4 fragColor;"//new_line("a")// &
    "uniform sampler2D u_font;"//new_line("a")// &
    "uniform vec4 u_color;"//new_line("a")// &
    "void main() {"//new_line("a")// &
    "  float alpha = texture(u_font, v_uv).r;"//new_line("a")// &
    "  fragColor = vec4(u_color.rgb, u_color.a * alpha);"//new_line("a")// &
    "}"
contains
  subroutine text_initialize(this)
    class(text_renderer), intent(inout) :: this
    integer(c_int8_t), target :: atlas(atlas_width * atlas_height)
    integer(c_int), target :: texture_id
    integer(c_int), target :: vao
    integer(c_int), target :: vbo

    if (this%texture_id /= 0_c_int) return
    atlas = build_atlas()
    call this%program%build(text_vertex_shader, text_fragment_shader, "bitmap text")
    this%screen_uniform = this%program%uniform("u_screen")
    this%color_uniform = this%program%uniform("u_color")
    this%texture_uniform = this%program%uniform("u_font")

    vao = 0_c_int
    vbo = 0_c_int
    texture_id = 0_c_int
    call gl_gen_vertex_arrays(1_c_int, c_loc(vao))
    call gl_gen_buffers(1_c_int, c_loc(vbo))
    call gl_gen_textures(1_c_int, c_loc(texture_id))
    this%vao = vao
    this%vbo = vbo
    this%texture_id = texture_id

    call gl_bind_vertex_array(this%vao)
    call gl_bind_buffer(gl_array_buffer, this%vbo)
    call gl_buffer_data(gl_array_buffer, 98304_c_int, c_null_ptr, gl_dynamic_draw)
    call gl_enable_vertex_attrib_array(0_c_int)
    call gl_vertex_attrib_pointer(0_c_int, 2_c_int, gl_float, gl_false, 16_c_int, c_null_ptr)
    call gl_enable_vertex_attrib_array(1_c_int)
    call gl_vertex_attrib_pointer(1_c_int, 2_c_int, gl_float, gl_false, 16_c_int, c_ptr_from_offset(8_c_int))
    call gl_bind_vertex_array(0_c_int)
    call gl_bind_buffer(gl_array_buffer, 0_c_int)

    call gl_bind_texture(gl_texture_2d, this%texture_id)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_min_filter, gl_nearest)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_mag_filter, gl_nearest)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_r8, atlas_width, atlas_height, 0_c_int, gl_red, gl_unsigned_byte, c_loc(atlas))
    call gl_bind_texture(gl_texture_2d, 0_c_int)
  end subroutine text_initialize

  subroutine text_begin_frame(this, framebuffer_width, framebuffer_height)
    class(text_renderer), intent(inout) :: this
    integer, intent(in), value :: framebuffer_width
    integer, intent(in), value :: framebuffer_height

    if (this%texture_id == 0_c_int) call this%initialize()
    call gl_enable(gl_blend)
    call gl_blend_func(gl_src_alpha, gl_one_minus_src_alpha)
    call this%program%use_program()
    call gl_uniform2f(this%screen_uniform, real(framebuffer_width, c_float), real(framebuffer_height, c_float))
    call gl_active_texture(gl_texture0)
    call gl_bind_texture(gl_texture_2d, this%texture_id)
    call gl_uniform1i(this%texture_uniform, 0_c_int)
  end subroutine text_begin_frame

  subroutine text_draw(this, text, x_px, y_px, scale, rgba)
    class(text_renderer), intent(inout) :: this
    character(len=*), intent(in) :: text
    integer, intent(in), value :: x_px
    integer, intent(in), value :: y_px
    integer, intent(in), value :: scale
    real, intent(in) :: rgba(4)
    real(c_float), allocatable, target :: vertices(:)
    integer :: cursor_x
    integer :: glyph
    integer :: i
    integer :: vertex_count

    if (len_trim(text) == 0) return
    allocate(vertices(24 * len_trim(text)))
    vertex_count = 0
    cursor_x = x_px

    do i = 1, len_trim(text)
      glyph = glyph_index(text(i:i))
      call append_glyph(vertices, vertex_count, glyph, cursor_x, y_px, scale)
      cursor_x = cursor_x + font_width * scale
    end do

    call this%program%use_program()
    call gl_uniform4f(this%color_uniform, real(rgba(1), c_float), real(rgba(2), c_float), &
      real(rgba(3), c_float), real(rgba(4), c_float))
    call gl_bind_vertex_array(this%vao)
    call gl_bind_buffer(gl_array_buffer, this%vbo)
    call gl_buffer_sub_data(gl_array_buffer, 0_c_int, int(size(vertices) * storage_size(vertices(1)) / 8, c_int), c_loc(vertices))
    call gl_draw_arrays(gl_triangles, 0_c_int, int(vertex_count / 4, c_int))
    call gl_bind_vertex_array(0_c_int)
    call gl_bind_buffer(gl_array_buffer, 0_c_int)
  end subroutine text_draw

  integer function text_measure(this, text, scale) result(width)
    class(text_renderer), intent(in) :: this
    character(len=*), intent(in) :: text
    integer, intent(in), value :: scale

    if (.false.) print *, this%texture_id
    width = len_trim(text) * font_width * scale
  end function text_measure

  subroutine text_destroy(this)
    class(text_renderer), intent(inout) :: this
    integer(c_int), target :: texture_id
    integer(c_int), target :: vao
    integer(c_int), target :: vbo

    vbo = this%vbo
    vao = this%vao
    texture_id = this%texture_id
    if (vbo /= 0_c_int) call gl_delete_buffers(1_c_int, c_loc(vbo))
    if (vao /= 0_c_int) call gl_delete_vertex_arrays(1_c_int, c_loc(vao))
    if (texture_id /= 0_c_int) call gl_delete_textures(1_c_int, c_loc(texture_id))
    call this%program%destroy()
    this%texture_id = 0_c_int
    this%vao = 0_c_int
    this%vbo = 0_c_int
  end subroutine text_destroy

  function build_atlas() result(atlas)
    integer(c_int8_t) :: atlas(atlas_width * atlas_height)
    integer :: glyph
    integer :: pixel_index
    integer :: row
    integer :: column
    integer :: x
    integer :: y

    atlas = 0_c_int8_t
    do glyph = 0, font_count - 1
      column = mod(glyph, glyphs_per_row)
      row = glyph / glyphs_per_row
      do y = 0, font_height - 1
        do x = 0, font_width - 1
          pixel_index = (row * font_height + y) * atlas_width + column * font_width + x + 1
          if (btest(int(font_rows(y + 1, glyph + 1), kind=4), font_width - 1 - x)) atlas(pixel_index) = 127_c_int8_t
        end do
      end do
    end do
  end function build_atlas

  subroutine append_glyph(vertices, cursor, glyph, x_px, y_px, scale)
    real(c_float), intent(inout) :: vertices(:)
    integer, intent(inout) :: cursor
    integer, intent(in), value :: glyph
    integer, intent(in), value :: x_px
    integer, intent(in), value :: y_px
    integer, intent(in), value :: scale
    real(c_float) :: u0
    real(c_float) :: u1
    real(c_float) :: v0
    real(c_float) :: v1
    real(c_float) :: x0
    real(c_float) :: x1
    real(c_float) :: y0
    real(c_float) :: y1
    integer :: atlas_column
    integer :: atlas_row

    atlas_column = mod(glyph, glyphs_per_row)
    atlas_row = glyph / glyphs_per_row
    u0 = real(atlas_column * font_width, c_float) / real(atlas_width, c_float)
    u1 = real((atlas_column + 1) * font_width, c_float) / real(atlas_width, c_float)
    v0 = real(atlas_row * font_height, c_float) / real(atlas_height, c_float)
    v1 = real((atlas_row + 1) * font_height, c_float) / real(atlas_height, c_float)
    x0 = real(x_px, c_float)
    x1 = real(x_px + font_width * scale, c_float)
    y0 = real(y_px, c_float)
    y1 = real(y_px + font_height * scale, c_float)

    call push_vertex(vertices, cursor, x0, y0, u0, v0)
    call push_vertex(vertices, cursor, x1, y0, u1, v0)
    call push_vertex(vertices, cursor, x1, y1, u1, v1)
    call push_vertex(vertices, cursor, x0, y0, u0, v0)
    call push_vertex(vertices, cursor, x1, y1, u1, v1)
    call push_vertex(vertices, cursor, x0, y1, u0, v1)
  end subroutine append_glyph

  subroutine push_vertex(vertices, cursor, x, y, u, v)
    real(c_float), intent(inout) :: vertices(:)
    integer, intent(inout) :: cursor
    real(c_float), intent(in), value :: x
    real(c_float), intent(in), value :: y
    real(c_float), intent(in), value :: u
    real(c_float), intent(in), value :: v

    vertices(cursor + 1) = x
    vertices(cursor + 2) = y
    vertices(cursor + 3) = u
    vertices(cursor + 4) = v
    cursor = cursor + 4
  end subroutine push_vertex

  integer function glyph_index(character_value) result(index)
    character(len=1), intent(in) :: character_value
    integer :: ascii_code

    ascii_code = iachar(character_value)
    if (ascii_code >= iachar("a") .and. ascii_code <= iachar("z")) ascii_code = ascii_code - 32
    if (ascii_code < 0 .or. ascii_code >= font_count) ascii_code = iachar("?")
    index = ascii_code
  end function glyph_index

  function c_ptr_from_offset(offset_bytes) result(pointer)
    integer(c_int), intent(in), value :: offset_bytes
    type(c_ptr) :: pointer
    integer(c_intptr_t) :: raw

    raw = int(offset_bytes, c_intptr_t)
    pointer = transfer(raw, pointer)
  end function c_ptr_from_offset
end module render_text_renderer
