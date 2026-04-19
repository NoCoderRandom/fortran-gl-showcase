module render_menu_background
  use, intrinsic :: iso_c_binding, only: c_float
  use app_runtime, only: runtime_framebuffer_size
  use gl_loader, only: gl_uniform1f, gl_uniform2f
  use render_fullscreen_quad, only: fullscreen_quad_cache
  use render_shader, only: shader_program
  implicit none (type, external)
  private

  public :: menu_background_renderer

  type :: menu_background_renderer
    type(fullscreen_quad_cache) :: quad
    type(shader_program) :: program
    integer :: screen_uniform = -1
    integer :: time_uniform = -1
    logical :: ready = .false.
  contains
    procedure :: destroy => menu_background_destroy
    procedure :: draw => menu_background_draw
    procedure :: initialize => menu_background_initialize
  end type menu_background_renderer

  character(len=*), parameter :: background_vertex_shader = &
    "#version 330 core"//new_line("a")// &
    "const vec2 positions[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));"//new_line("a")// &
    "out vec2 uv;"//new_line("a")// &
    "void main() {"//new_line("a")// &
    "  vec2 pos = positions[gl_VertexID];"//new_line("a")// &
    "  uv = pos * 0.5 + 0.5;"//new_line("a")// &
    "  gl_Position = vec4(pos, 0.0, 1.0);"//new_line("a")// &
    "}"

  character(len=*), parameter :: background_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec2 uv;"//new_line("a")// &
    "out vec4 fragColor;"//new_line("a")// &
    "uniform vec2 u_screen;"//new_line("a")// &
    "uniform float u_time;"//new_line("a")// &
    "void main() {"//new_line("a")// &
    "  float vignette = smoothstep(1.2, 0.2, distance(uv, vec2(0.5, 0.45)));"//new_line("a")// &
    "  float band = 0.04 * sin(u_time * 0.35 + uv.y * 5.5);"//new_line("a")// &
    "  vec3 top = vec3(0.05, 0.07, 0.11);"//new_line("a")// &
    "  vec3 bottom = vec3(0.02, 0.03, 0.06);"//new_line("a")// &
    "  vec3 color = mix(top, bottom, clamp(uv.y + band, 0.0, 1.0));"//new_line("a")// &
    "  color += vec3(0.02, 0.02, 0.01) * vignette;"//new_line("a")// &
    "  fragColor = vec4(color, 1.0);"//new_line("a")// &
    "}"
contains
  subroutine menu_background_initialize(this)
    class(menu_background_renderer), intent(inout) :: this

    if (this%ready) return
    call this%quad%initialize()
    call this%program%build(background_vertex_shader, background_fragment_shader, "menu background")
    this%screen_uniform = this%program%uniform("u_screen")
    this%time_uniform = this%program%uniform("u_time")
    this%ready = .true.
  end subroutine menu_background_initialize

  subroutine menu_background_draw(this, time_seconds)
    class(menu_background_renderer), intent(inout) :: this
    real(c_float), intent(in), value :: time_seconds
    integer :: width
    integer :: height

    if (.not. this%ready) call this%initialize()
    call runtime_framebuffer_size(width, height)
    call this%program%use_program()
    call gl_uniform2f(this%screen_uniform, real(width, c_float), real(height, c_float))
    call gl_uniform1f(this%time_uniform, time_seconds)
    call this%quad%draw()
  end subroutine menu_background_draw

  subroutine menu_background_destroy(this)
    class(menu_background_renderer), intent(inout) :: this

    call this%program%destroy()
    call this%quad%destroy()
    this%ready = .false.
  end subroutine menu_background_destroy
end module render_menu_background

