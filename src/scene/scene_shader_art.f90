module scene_shader_art
  use, intrinsic :: iso_c_binding, only: c_float, c_int
  use app_runtime, only: runtime_draw_text, runtime_framebuffer_size, runtime_is_offline, runtime_measure_text
  use app_runtime, only: runtime_request_menu, runtime_text_begin_frame, runtime_was_pressed
  use core_kinds, only: real64
  use core_text_file, only: read_text_file
  use gl_loader, only: gl_uniform1f, gl_uniform2f
  use platform_input, only: key_escape, key_h, key_r, key_space
  use render_fullscreen_quad, only: fullscreen_quad_cache
  use render_shader, only: shader_program
  use scene_base, only: post_settings_t, scene_type, tone_aces, tone_reinhard
  implicit none (type, external)
  private

  integer, parameter :: scene_waves = 1
  integer, parameter :: scene_bloom = 2
  integer, parameter :: scene_tunnel = 3
  integer, parameter :: scene_color = 4

  public :: shader_art_scene_type
  public :: setup_color_field_scene
  public :: setup_hdr_bloom_scene
  public :: setup_procedural_waves_scene
  public :: setup_tunnel_flythrough_scene

  type, extends(scene_type) :: shader_art_scene_type
    type(fullscreen_quad_cache) :: quad
    type(shader_program) :: program
    integer(c_int) :: resolution_uniform = -1
    integer(c_int) :: time_uniform = -1
    integer :: kind = 0
    logical :: paused = .false.
    logical :: show_hud = .true.
    real(real64) :: scene_time = 0.0_real64
  contains
    procedure :: destroy => shader_art_destroy
    procedure :: get_name => shader_art_get_name
    procedure :: get_post_settings => shader_art_get_post_settings
    procedure :: init => shader_art_init
    procedure :: render => shader_art_render
    procedure :: update => shader_art_update
  end type shader_art_scene_type
contains
  subroutine setup_procedural_waves_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(shader_art_scene_type :: scene)
    select type (scene)
    type is (shader_art_scene_type)
      scene%kind = scene_waves
    class default
      error stop "Unexpected procedural waves allocation failure."
    end select
  end subroutine setup_procedural_waves_scene

  subroutine setup_hdr_bloom_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(shader_art_scene_type :: scene)
    select type (scene)
    type is (shader_art_scene_type)
      scene%kind = scene_bloom
    class default
      error stop "Unexpected HDR bloom allocation failure."
    end select
  end subroutine setup_hdr_bloom_scene

  subroutine setup_tunnel_flythrough_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(shader_art_scene_type :: scene)
    select type (scene)
    type is (shader_art_scene_type)
      scene%kind = scene_tunnel
    class default
      error stop "Unexpected tunnel flythrough allocation failure."
    end select
  end subroutine setup_tunnel_flythrough_scene

  subroutine setup_color_field_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(shader_art_scene_type :: scene)
    select type (scene)
    type is (shader_art_scene_type)
      scene%kind = scene_color
    class default
      error stop "Unexpected color field allocation failure."
    end select
  end subroutine setup_color_field_scene

  subroutine shader_art_init(this)
    class(shader_art_scene_type), intent(inout) :: this
    character(len=:), allocatable :: fragment_source
    character(len=:), allocatable :: vertex_source

    call this%quad%initialize()
    vertex_source = read_text_file("assets/shaders/fractal2d.vert")
    fragment_source = read_text_file(fragment_path(this%kind))
    call this%program%build(vertex_source, fragment_source, trim(display_name(this%kind)))
    this%resolution_uniform = this%program%uniform("u_resolution")
    this%time_uniform = this%program%uniform("u_time")
    this%paused = .false.
    this%show_hud = .true.
    this%scene_time = 0.0_real64
  end subroutine shader_art_init

  subroutine shader_art_destroy(this)
    class(shader_art_scene_type), intent(inout) :: this

    call this%program%destroy()
    call this%quad%destroy()
  end subroutine shader_art_destroy

  subroutine shader_art_get_name(this, value)
    class(shader_art_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    value = scene_name(this%kind)
  end subroutine shader_art_get_name

  function shader_art_get_post_settings(this) result(settings)
    class(shader_art_scene_type), intent(in) :: this
    type(post_settings_t) :: settings

    select case (this%kind)
    case (scene_waves)
      settings%bloom_strength = 0.75
      settings%bloom_threshold = 1.10
      settings%tone_map_mode = tone_aces
      settings%vignette_strength = 0.18
      settings%grain_strength = 0.012
    case (scene_bloom)
      settings%bloom_strength = 1.75
      settings%bloom_threshold = 0.72
      settings%tone_map_mode = tone_aces
      settings%vignette_strength = 0.14
      settings%grain_strength = 0.010
      settings%chromatic_ab = .true.
    case (scene_tunnel)
      settings%bloom_strength = 1.05
      settings%bloom_threshold = 0.96
      settings%tone_map_mode = tone_aces
      settings%vignette_strength = 0.38
      settings%grain_strength = 0.018
      settings%chromatic_ab = .true.
    case (scene_color)
      settings%bloom_strength = 0.65
      settings%bloom_threshold = 1.08
      settings%tone_map_mode = tone_reinhard
      settings%vignette_strength = 0.12
      settings%grain_strength = 0.010
    case default
      settings = post_settings_t()
    end select
  end function shader_art_get_post_settings

  subroutine shader_art_update(this, delta_seconds)
    class(shader_art_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
    if (runtime_was_pressed(key_escape)) call runtime_request_menu()
    if (runtime_was_pressed(key_h)) this%show_hud = .not. this%show_hud
    if (runtime_was_pressed(key_space)) this%paused = .not. this%paused
    if (runtime_was_pressed(key_r)) this%scene_time = 0.0_real64
    if (.not. this%paused) this%scene_time = this%scene_time + delta_seconds
  end subroutine shader_art_update

  subroutine shader_art_render(this)
    class(shader_art_scene_type), intent(inout) :: this
    integer :: height
    integer :: width

    call runtime_framebuffer_size(width, height)
    call this%program%use_program()
    call gl_uniform2f(this%resolution_uniform, real(width, c_float), real(height, c_float))
    call gl_uniform1f(this%time_uniform, real(this%scene_time, c_float))
    call this%quad%draw()

    if (runtime_is_offline()) return
    if (.not. this%show_hud) return
    call draw_hud(this, width, height)
  end subroutine shader_art_render

  subroutine draw_hud(this, width, height)
    class(shader_art_scene_type), intent(in) :: this
    integer, intent(in), value :: width
    integer, intent(in), value :: height
    character(len=96) :: controls
    character(len=96) :: subtitle
    character(len=64) :: time_line
    real(c_float) :: accent(4)
    real(c_float) :: body(4)
    real(c_float) :: dim(4)

    accent = [0.95_c_float, 0.84_c_float, 0.49_c_float, 1.0_c_float]
    body = [0.84_c_float, 0.88_c_float, 0.94_c_float, 1.0_c_float]
    dim = [0.60_c_float, 0.65_c_float, 0.73_c_float, 1.0_c_float]

    call runtime_text_begin_frame()
    call runtime_draw_text(trim(display_name(this%kind)), 28, 30, 3, accent)
    subtitle = description_line(this%kind)
    call runtime_draw_text(trim(subtitle), 28, 72, 2, body)
    write (time_line, '(a,f6.2,a)') "TIME: ", this%scene_time, " S"
    call runtime_draw_text(trim(time_line), 28, height - 82, 2, body)
    if (this%paused) then
      call runtime_draw_text("PAUSED", 28, height - 50, 2, accent)
    end if
    controls = "SPACE PAUSE  R RESET  H HUD  ESC MENU"
    call runtime_draw_text(trim(controls), &
      max(24, width - runtime_measure_text(trim(controls), 2) - 24), &
      height - 50, 2, dim)
  end subroutine draw_hud

  pure function scene_name(kind) result(value)
    integer, intent(in), value :: kind
    character(len=64) :: value

    select case (kind)
    case (scene_waves)
      value = "procedural_waves"
    case (scene_bloom)
      value = "hdr_bloom_demo"
    case (scene_tunnel)
      value = "tunnel_flythrough"
    case (scene_color)
      value = "color_field"
    case default
      value = "shader_art_unknown"
    end select
  end function scene_name

  pure function display_name(kind) result(value)
    integer, intent(in), value :: kind
    character(len=96) :: value

    select case (kind)
    case (scene_waves)
      value = "Procedural Waves"
    case (scene_bloom)
      value = "HDR Bloom Demo"
    case (scene_tunnel)
      value = "Tunnel Flythrough"
    case (scene_color)
      value = "Color Field"
    case default
      value = "Unknown Shader Scene"
    end select
  end function display_name

  pure function description_line(kind) result(value)
    integer, intent(in), value :: kind
    character(len=96) :: value

    select case (kind)
    case (scene_waves)
      value = "Layered ocean ridges with fake caustics and soft highlights."
    case (scene_bloom)
      value = "Emissive rings and starbursts tuned to stress the HDR bloom path."
    case (scene_tunnel)
      value = "Palette-driven tunnel flight with stripe bands and central glow."
    case (scene_color)
      value = "Ambient gradient field with drifting contours for idle playback."
    case default
      value = "Unknown shader-art scene."
    end select
  end function description_line

  pure function fragment_path(kind) result(value)
    integer, intent(in), value :: kind
    character(len=128) :: value

    select case (kind)
    case (scene_waves)
      value = "assets/shaders/procedural_waves.frag"
    case (scene_bloom)
      value = "assets/shaders/hdr_bloom_demo.frag"
    case (scene_tunnel)
      value = "assets/shaders/tunnel_flythrough.frag"
    case (scene_color)
      value = "assets/shaders/color_field.frag"
    case default
      value = "assets/shaders/color_field.frag"
    end select
  end function fragment_path
end module scene_shader_art
