module render_fullscreen_quad
  use, intrinsic :: iso_c_binding, only: c_int, c_loc
  use gl_loader, only: gl_bind_vertex_array, gl_delete_vertex_arrays, gl_draw_arrays, gl_gen_vertex_arrays, gl_triangles
  implicit none (type, external)
  private

  public :: fullscreen_quad_cache

  type :: fullscreen_quad_cache
    integer(c_int) :: vao = 0_c_int
  contains
    procedure :: destroy => fullscreen_quad_destroy
    procedure :: draw => fullscreen_quad_draw
    procedure :: initialize => fullscreen_quad_initialize
  end type fullscreen_quad_cache
contains
  subroutine fullscreen_quad_initialize(this)
    class(fullscreen_quad_cache), intent(inout) :: this
    integer(c_int), target :: vao

    if (this%vao /= 0_c_int) return
    vao = 0_c_int
    call gl_gen_vertex_arrays(1_c_int, c_loc(vao))
    this%vao = vao
  end subroutine fullscreen_quad_initialize

  subroutine fullscreen_quad_draw(this)
    class(fullscreen_quad_cache), intent(in) :: this

    call gl_bind_vertex_array(this%vao)
    call gl_draw_arrays(gl_triangles, 0_c_int, 3_c_int)
    call gl_bind_vertex_array(0_c_int)
  end subroutine fullscreen_quad_draw

  subroutine fullscreen_quad_destroy(this)
    class(fullscreen_quad_cache), intent(inout) :: this
    integer(c_int), target :: vao

    vao = this%vao
    if (vao /= 0_c_int) call gl_delete_vertex_arrays(1_c_int, c_loc(vao))
    this%vao = 0_c_int
  end subroutine fullscreen_quad_destroy
end module render_fullscreen_quad
