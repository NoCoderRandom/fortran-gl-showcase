module scene_fractal2d
  use, intrinsic :: iso_c_binding, only: c_double, c_float, c_int, c_loc
  use app_runtime, only: runtime_draw_text, runtime_elapsed, runtime_framebuffer_size, runtime_is_down, runtime_measure_text
  use app_runtime, only: runtime_mouse_delta, runtime_mouse_is_down, runtime_request_menu, runtime_scroll_delta
  use app_runtime, only: runtime_is_offline, runtime_text_begin_frame, runtime_was_pressed
  use core_kinds, only: real64
  use core_text_file, only: read_text_file
  use gl_loader, only: gl_active_texture, gl_bind_texture, gl_clamp_to_edge, gl_delete_textures, gl_float, gl_gen_textures
  use gl_loader, only: gl_linear, gl_rgba, gl_rgba16f, gl_tex_image_2d, gl_tex_parameteri, gl_texture0, gl_texture_2d
  use gl_loader, only: gl_texture_mag_filter, gl_texture_min_filter, gl_texture_wrap_s, gl_texture_wrap_t
  use gl_loader, only: gl_uniform1f, gl_uniform1i, gl_uniform2f
  use platform_input, only: key_a, key_d, key_down, key_e, key_escape, key_h, key_left, key_left_bracket
  use platform_input, only: key_page_down, key_page_up, key_q, key_r, key_right, key_right_bracket, key_s
  use platform_input, only: key_space, key_t, key_up, key_w, mouse_button_left
  use render_fullscreen_quad, only: fullscreen_quad_cache
  use render_palette_data, only: palette_count, palette_names, palette_rgba, palette_width
  use render_shader, only: shader_program
  use scene_base, only: post_settings_t, scene_type, tone_aces
  implicit none (type, external)
  private

  integer, parameter :: fractal_mandelbrot = 1
  integer, parameter :: fractal_julia = 2
  integer, parameter :: fractal_burning_ship = 3
  integer, parameter :: autopilot_target_count = 3
  real(real64), parameter :: min_scale_limit = 5.0e-6_real64
  real(real64), parameter :: autopilot_target_x(autopilot_target_count) = [ &
    -0.743643887037151_real64, -0.775683770000000_real64, -0.747178300000000_real64 ]
  real(real64), parameter :: autopilot_target_y(autopilot_target_count) = [ &
    0.131825904205330_real64, 0.136467370000000_real64, 0.101848100000000_real64 ]
  real(real64), parameter :: autopilot_target_scale(autopilot_target_count) = [ &
    4.5e-3_real64, 1.2e-3_real64, 2.5e-3_real64 ]

  public :: fractal2d_scene_type
  public :: setup_fractal2d_scene

  type, extends(scene_type) :: fractal2d_scene_type
    type(fullscreen_quad_cache) :: quad
    type(shader_program) :: program
    integer(c_int) :: palette_texture = 0_c_int
    integer(c_int) :: center_x_uniform = -1
    integer(c_int) :: center_y_uniform = -1
    integer(c_int) :: fractal_uniform = -1
    integer(c_int) :: iter_uniform = -1
    integer(c_int) :: julia_uniform = -1
    integer(c_int) :: orbit_uniform = -1
    integer(c_int) :: palette_phase_uniform = -1
    integer(c_int) :: palette_uniform = -1
    integer(c_int) :: resolution_uniform = -1
    integer(c_int) :: scale_uniform = -1
    integer(c_int) :: time_uniform = -1
    integer :: fractal_kind = fractal_mandelbrot
    integer :: orbit_mode = 0
    integer :: palette_index = 1
    logical :: autopilot_enabled = .true.
    logical :: autopilot_active = .false.
    integer :: autopilot_target_index = 1
    logical :: show_hud = .true.
    real(real64) :: autopilot_stage_seconds = 0.0_real64
    real(real64) :: center_x = -0.55_real64
    real(real64) :: center_y = 0.0_real64
    real(real64) :: idle_seconds = 0.0_real64
    real(real64) :: julia_phase = 0.0_real64
    real(real64) :: scale = 2.8_real64
  contains
    procedure :: destroy => fractal_destroy
    procedure :: get_name => fractal_get_name
    procedure :: get_post_settings => fractal_get_post_settings
    procedure :: init => fractal_init
    procedure :: render => fractal_render
    procedure :: update => fractal_update
  end type fractal2d_scene_type

contains
  subroutine setup_fractal2d_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(fractal2d_scene_type :: scene)
  end subroutine setup_fractal2d_scene

  subroutine fractal_init(this)
    class(fractal2d_scene_type), intent(inout) :: this
    character(len=:), allocatable :: fragment_source
    character(len=:), allocatable :: vertex_source

    call this%quad%initialize()
    vertex_source = read_text_file("assets/shaders/fractal2d.vert")
    fragment_source = read_text_file("assets/shaders/fractal2d.frag")
    call this%program%build(vertex_source, fragment_source, "fractal explorer")
    this%resolution_uniform = this%program%uniform("u_resolution")
    this%center_x_uniform = this%program%uniform("u_center_x")
    this%center_y_uniform = this%program%uniform("u_center_y")
    this%scale_uniform = this%program%uniform("u_scale")
    this%julia_uniform = this%program%uniform("u_julia_c")
    this%palette_uniform = this%program%uniform("u_palette")
    this%palette_phase_uniform = this%program%uniform("u_palette_phase")
    this%time_uniform = this%program%uniform("u_time")
    this%fractal_uniform = this%program%uniform("u_fractal_type")
    this%iter_uniform = this%program%uniform("u_max_iter")
    this%orbit_uniform = this%program%uniform("u_orbit_trap_mode")
    call ensure_palette_texture(this)
    call reset_view(this)
  end subroutine fractal_init

  subroutine fractal_destroy(this)
    class(fractal2d_scene_type), intent(inout) :: this
    integer(c_int), target :: texture_id

    texture_id = this%palette_texture
    if (texture_id /= 0_c_int) call gl_delete_textures(1_c_int, c_loc(texture_id))
    this%palette_texture = 0_c_int
    call this%program%destroy()
    call this%quad%destroy()
  end subroutine fractal_destroy

  subroutine fractal_get_name(this, value)
    class(fractal2d_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "fractal_explorer"
  end subroutine fractal_get_name

  function fractal_get_post_settings(this) result(settings)
    class(fractal2d_scene_type), intent(in) :: this
    type(post_settings_t) :: settings

    if (.false.) print *, same_type_as(this, this)
    settings%bloom_strength = 0.8
    settings%bloom_threshold = 1.0
    settings%tone_map_mode = tone_aces
    settings%vignette_strength = 0.3
    settings%grain_strength = 0.02
  end function fractal_get_post_settings

  subroutine fractal_update(this, delta_seconds)
    class(fractal2d_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds
    real(c_double) :: mouse_dx
    real(c_double) :: mouse_dy
    real(c_double) :: scroll_dx
    real(c_double) :: scroll_dy
    real(real64) :: aspect
    real(real64) :: pan_step
    real(real64) :: target_x
    real(real64) :: target_y
    integer :: width
    integer :: height
    logical :: activity
    logical :: pan_down
    logical :: pan_left
    logical :: pan_right
    logical :: pan_up

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."

    call runtime_framebuffer_size(width, height)
    aspect = max(1.0_real64, real(width, real64)) / max(1.0_real64, real(height, real64))
    pan_step = this%scale * delta_seconds * 0.7_real64
    activity = .false.

    if (runtime_was_pressed(key_escape)) call runtime_request_menu()
    if (runtime_was_pressed(key_h)) then
      this%show_hud = .not. this%show_hud
      activity = .true.
    end if
    if (runtime_was_pressed(key_r)) then
      call reset_view(this)
      activity = .true.
    end if
    if (runtime_was_pressed(key_space)) then
      this%autopilot_enabled = .not. this%autopilot_enabled
      this%autopilot_active = .false.
      this%idle_seconds = 0.0_real64
      activity = .true.
    end if
    if (runtime_was_pressed(key_t)) then
      this%orbit_mode = mod(this%orbit_mode + 1, 3)
      activity = .true.
    end if
    if (runtime_was_pressed(key_left_bracket)) then
      this%fractal_kind = merge(this%fractal_kind - 1, fractal_burning_ship, this%fractal_kind > fractal_mandelbrot)
      if (this%fractal_kind < fractal_mandelbrot) this%fractal_kind = fractal_burning_ship
      activity = .true.
    end if
    if (runtime_was_pressed(key_right_bracket)) then
      this%fractal_kind = this%fractal_kind + 1
      if (this%fractal_kind > fractal_burning_ship) this%fractal_kind = fractal_mandelbrot
      activity = .true.
    end if
    if (runtime_was_pressed(key_page_up)) then
      this%palette_index = this%palette_index + 1
      if (this%palette_index > palette_count) this%palette_index = 1
      activity = .true.
    end if
    if (runtime_was_pressed(key_page_down)) then
      this%palette_index = this%palette_index - 1
      if (this%palette_index < 1) this%palette_index = palette_count
      activity = .true.
    end if

    pan_left = runtime_is_down(key_left)
    if (.not. pan_left) pan_left = runtime_is_down(key_a)
    pan_right = runtime_is_down(key_right)
    if (.not. pan_right) pan_right = runtime_is_down(key_d)
    pan_up = runtime_is_down(key_up)
    if (.not. pan_up) pan_up = runtime_is_down(key_w)
    pan_down = runtime_is_down(key_down)
    if (.not. pan_down) pan_down = runtime_is_down(key_s)

    if (pan_left) then
      this%center_x = this%center_x - pan_step * aspect
      activity = .true.
    end if
    if (pan_right) then
      this%center_x = this%center_x + pan_step * aspect
      activity = .true.
    end if
    if (pan_up) then
      this%center_y = this%center_y - pan_step
      activity = .true.
    end if
    if (pan_down) then
      this%center_y = this%center_y + pan_step
      activity = .true.
    end if
    if (runtime_is_down(key_q)) then
      this%scale = min(4.0_real64, this%scale * exp(delta_seconds * 1.6_real64))
      activity = .true.
    end if
    if (runtime_is_down(key_e)) then
      this%scale = max(min_scale_limit, this%scale * exp(-delta_seconds * 1.6_real64))
      activity = .true.
    end if

    call runtime_scroll_delta(scroll_dx, scroll_dy)
    if (abs(scroll_dx) > 0.0_c_double .or. abs(scroll_dy) > 0.0_c_double) then
      this%scale = max(min_scale_limit, min(4.0_real64, this%scale * exp(-0.18_real64 * real(scroll_dy, real64))))
      activity = .true.
    end if

    call runtime_mouse_delta(mouse_dx, mouse_dy)
    if (runtime_mouse_is_down(mouse_button_left)) then
      if (abs(mouse_dx) > 0.0_c_double .or. abs(mouse_dy) > 0.0_c_double) then
        this%center_x = this%center_x - this%scale * real(mouse_dx, real64) / max(1.0_real64, real(height, real64))
        this%center_y = this%center_y + this%scale * real(mouse_dy, real64) / max(1.0_real64, real(height, real64))
        activity = .true.
      end if
    end if

    if (activity) then
      this%idle_seconds = 0.0_real64
      this%autopilot_active = .false.
      this%autopilot_stage_seconds = 0.0_real64
    else
      this%idle_seconds = this%idle_seconds + delta_seconds
      if (this%autopilot_enabled .and. this%idle_seconds >= 5.0_real64) then
        this%autopilot_active = .true.
        this%fractal_kind = fractal_mandelbrot
        this%autopilot_stage_seconds = this%autopilot_stage_seconds + delta_seconds
        target_x = autopilot_target_x(this%autopilot_target_index) + 0.0012_real64 * &
          sin(this%autopilot_stage_seconds * 0.23_real64 + real(this%autopilot_target_index, real64))
        target_y = autopilot_target_y(this%autopilot_target_index) + 0.0010_real64 * &
          cos(this%autopilot_stage_seconds * 0.19_real64 + 1.7_real64 * real(this%autopilot_target_index, real64))
        this%center_x = this%center_x + (target_x - this%center_x) * min(1.0_real64, delta_seconds * 0.6_real64)
        this%center_y = this%center_y + (target_y - this%center_y) * min(1.0_real64, delta_seconds * 0.6_real64)
        this%scale = this%scale + (autopilot_target_scale(this%autopilot_target_index) - this%scale) * &
          min(1.0_real64, delta_seconds * 0.35_real64)
        this%scale = max(min_scale_limit, this%scale)
        if (this%autopilot_stage_seconds >= 8.0_real64) then
          this%autopilot_stage_seconds = 0.0_real64
          this%autopilot_target_index = mod(this%autopilot_target_index, autopilot_target_count) + 1
        end if
      end if
    end if

    this%julia_phase = this%julia_phase + delta_seconds
  end subroutine fractal_update

  subroutine fractal_render(this)
    class(fractal2d_scene_type), intent(inout) :: this
    character(len=48) :: autopilot_text
    character(len=64) :: fractal_line
    character(len=64) :: iter_line
    character(len=64) :: palette_line
    character(len=64) :: zoom_line
    integer :: height
    integer :: iter_cap
    integer :: width
    real(c_float) :: center_x_hi
    real(c_float) :: center_x_lo
    real(c_float) :: center_y_hi
    real(c_float) :: center_y_lo
    real(c_float), target :: strip(4, palette_width)
    real(real64) :: phase
    real(c_float) :: scale_hi
    real(c_float) :: scale_lo
    real(real64) :: zoom_value

    call runtime_framebuffer_size(width, height)
    iter_cap = compute_iteration_cap(this%scale)
    zoom_value = 1.0_real64 / max(this%scale, 1.0e-15_real64)
    phase = 0.0_real64
    if (this%autopilot_active) phase = 0.05_real64 * runtime_elapsed()
    center_x_hi = real(this%center_x, c_float)
    center_x_lo = real(this%center_x - real(center_x_hi, real64), c_float)
    center_y_hi = real(this%center_y, c_float)
    center_y_lo = real(this%center_y - real(center_y_hi, real64), c_float)
    scale_hi = real(this%scale, c_float)
    scale_lo = real(this%scale - real(scale_hi, real64), c_float)

    strip = palette_rgba(:, :, this%palette_index)
    call gl_active_texture(gl_texture0)
    call gl_bind_texture(gl_texture_2d, this%palette_texture)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, palette_width, 1_c_int, 0_c_int, gl_rgba, gl_float, c_loc(strip))

    call this%program%use_program()
    call gl_uniform2f(this%resolution_uniform, real(width, c_float), real(height, c_float))
    call gl_uniform2f(this%center_x_uniform, center_x_hi, center_x_lo)
    call gl_uniform2f(this%center_y_uniform, center_y_hi, center_y_lo)
    call gl_uniform2f(this%scale_uniform, scale_hi, scale_lo)
    call gl_uniform2f(this%julia_uniform, real(julia_cx(this), c_float), real(julia_cy(this), c_float))
    call gl_uniform1i(this%palette_uniform, 0_c_int)
    call gl_uniform1f(this%palette_phase_uniform, real(phase + real(this%palette_index - 1, real64) * 0.11_real64, c_float))
    call gl_uniform1f(this%time_uniform, real(runtime_elapsed(), c_float))
    call gl_uniform1i(this%fractal_uniform, int(this%fractal_kind - 1, c_int))
    call gl_uniform1i(this%iter_uniform, int(iter_cap, c_int))
    call gl_uniform1i(this%orbit_uniform, int(this%orbit_mode, c_int))
    call this%quad%draw()

    if (runtime_is_offline()) return
    if (.not. this%show_hud) return
    call runtime_text_begin_frame()
    write (fractal_line, '(a,a)') "FRACTAL: ", trim(fractal_name(this%fractal_kind))
    write (zoom_line, '(a,es11.3)') "ZOOM: ", zoom_value
    write (iter_line, '(a,i0)') "ITER: ", iter_cap
    write (palette_line, '(a,a)') "PALETTE: ", trim(palette_names(this%palette_index))
    if (this%autopilot_enabled) then
      autopilot_text = "AUTOPILOT: ON"
    else
      autopilot_text = "AUTOPILOT: OFF"
    end if
    call runtime_draw_text(fractal_line, 28, height - 204, 2, [0.96, 0.88, 0.58, 1.0])
    call runtime_draw_text(zoom_line, 28, height - 172, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(iter_line, 28, height - 140, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(palette_line, 28, height - 108, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(autopilot_text, 28, height - 76, 2, [0.62, 0.67, 0.75, 1.0])
    call runtime_draw_text("[] FRACTAL  PGUP/PGDN PALETTE  T TRAP  SPACE AUTOPILOT  ESC MENU", &
      max(24, width - runtime_measure_text("[] FRACTAL  PGUP/PGDN PALETTE  T TRAP  SPACE AUTOPILOT  ESC MENU", 2) - 24), &
      height - 44, 2, [0.62, 0.67, 0.75, 1.0])
  end subroutine fractal_render

  subroutine ensure_palette_texture(this)
    class(fractal2d_scene_type), intent(inout) :: this
    integer(c_int), target :: texture_id
    real(c_float), target :: strip(4, palette_width)

    if (this%palette_texture /= 0_c_int) return
    texture_id = 0_c_int
    strip = palette_rgba(:, :, 1)
    call gl_gen_textures(1_c_int, c_loc(texture_id))
    this%palette_texture = texture_id
    call gl_bind_texture(gl_texture_2d, this%palette_texture)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_min_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_mag_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, palette_width, 1_c_int, 0_c_int, gl_rgba, gl_float, c_loc(strip))
    call gl_bind_texture(gl_texture_2d, 0_c_int)
  end subroutine ensure_palette_texture

  subroutine reset_view(this)
    class(fractal2d_scene_type), intent(inout) :: this

    this%idle_seconds = 0.0_real64
    this%autopilot_active = .false.
    this%autopilot_stage_seconds = 0.0_real64
    this%autopilot_target_index = 1
    select case (this%fractal_kind)
    case (fractal_mandelbrot)
      this%center_x = -0.55_real64
      this%center_y = 0.0_real64
      this%scale = 2.8_real64
    case (fractal_julia)
      this%center_x = 0.0_real64
      this%center_y = 0.0_real64
      this%scale = 2.6_real64
    case default
      this%center_x = -0.45_real64
      this%center_y = -0.45_real64
      this%scale = 2.8_real64
    end select
  end subroutine reset_view

  integer function compute_iteration_cap(scale_value) result(iter_cap)
    real(real64), intent(in), value :: scale_value
    real(real64) :: zoom_depth

    zoom_depth = max(0.0_real64, -log10(max(scale_value, min_scale_limit)))
    iter_cap = 224 + int(zoom_depth * 110.0_real64)
    iter_cap = min(960, max(224, iter_cap))
  end function compute_iteration_cap

  character(len=24) function fractal_name(kind) result(name)
    integer, intent(in), value :: kind

    select case (kind)
    case (fractal_mandelbrot)
      name = "Mandelbrot"
    case (fractal_julia)
      name = "Julia"
    case default
      name = "Burning Ship"
    end select
  end function fractal_name

  real(real64) function julia_cx(this) result(value)
    class(fractal2d_scene_type), intent(in) :: this

    value = -0.78_real64 + 0.22_real64 * cos(this%julia_phase * 0.29_real64)
  end function julia_cx

  real(real64) function julia_cy(this) result(value)
    class(fractal2d_scene_type), intent(in) :: this

    value = 0.15_real64 + 0.18_real64 * sin(this%julia_phase * 0.41_real64)
  end function julia_cy
end module scene_fractal2d
