module render_fullscreen_quad
  implicit none (type, external)
  private

  public :: fullscreen_quad_cache

  type :: fullscreen_quad_cache
    logical :: is_ready = .false.
  contains
    procedure :: destroy => fullscreen_quad_destroy
    procedure :: draw => fullscreen_quad_draw
    procedure :: initialize => fullscreen_quad_initialize
  end type fullscreen_quad_cache
contains
  subroutine fullscreen_quad_initialize(this)
    class(fullscreen_quad_cache), intent(inout) :: this

    this%is_ready = .true.
  end subroutine fullscreen_quad_initialize

  subroutine fullscreen_quad_draw(this)
    class(fullscreen_quad_cache), intent(in) :: this

    if (.not. this%is_ready) return
  end subroutine fullscreen_quad_draw

  subroutine fullscreen_quad_destroy(this)
    class(fullscreen_quad_cache), intent(inout) :: this

    this%is_ready = .false.
  end subroutine fullscreen_quad_destroy
end module render_fullscreen_quad

