module scene_combined
  use, intrinsic :: iso_c_binding, only: c_float, c_int, c_loc, c_null_ptr
  use anim_camera_spline, only: camera_spline
  use anim_timeline, only: timeline_type
  use anim_tiny_parser, only: load_timeline_file
  use app_runtime, only: runtime_draw_text, runtime_elapsed, runtime_framebuffer_size, runtime_measure_text
  use app_runtime, only: runtime_is_offline, runtime_request_menu, runtime_text_begin_frame, runtime_was_pressed
  use core_kinds, only: real64
  use core_text_file, only: read_text_file
  use gl_loader, only: gl_active_texture, gl_bind_framebuffer, gl_bind_texture, gl_bind_vertex_array, gl_blend
  use gl_loader, only: gl_blend_func, gl_check_framebuffer_status, gl_clear, gl_clear_color, gl_color_attachment0
  use gl_loader, only: gl_color_buffer_bit, gl_delete_framebuffers, gl_delete_textures, gl_delete_vertex_arrays
  use gl_loader, only: gl_disable, gl_draw_arrays, gl_enable, gl_float, gl_framebuffer, gl_framebuffer_complete
  use gl_loader, only: gl_framebuffer_binding, gl_get_integerv
  use gl_loader, only: gl_framebuffer_texture_2d, gl_gen_framebuffers, gl_gen_textures, gl_gen_vertex_arrays
  use gl_loader, only: gl_linear, gl_one, gl_one_minus_src_alpha, gl_points, gl_program_point_size, gl_rgba
  use gl_loader, only: gl_rgba16f, gl_tex_image_2d, gl_tex_parameteri, gl_texture0, gl_texture1, gl_texture_2d
  use gl_loader, only: gl_texture_mag_filter, gl_texture_min_filter, gl_texture_wrap_s, gl_texture_wrap_t
  use gl_loader, only: gl_uniform1f, gl_uniform1i, gl_uniform2f, gl_uniform3f, gl_viewport
  use gl_loader, only: gl_clamp_to_edge, gl_src_alpha
  use platform_input, only: key_escape, key_left, key_period, key_r, key_right, key_space
  use render_fullscreen_quad, only: fullscreen_quad_cache
  use render_palette_data, only: palette_rgba, palette_width
  use render_shader, only: shader_program
  use scene_base, only: post_settings_t, scene_type, tone_aces
  implicit none (type, external)
  private

  real(real64), parameter :: act2_start = 20.0_real64
  real(real64), parameter :: act3_start = 40.0_real64
  real(real64), parameter :: crossfade_span = 2.0_real64
  real(real64), parameter :: target_fps = 60.0_real64

  public :: combined_scene_type
  public :: setup_combined_scene

  type, extends(scene_type) :: combined_scene_type
    type(timeline_type) :: timeline
    type(camera_spline) :: mandel_camera
    type(fullscreen_quad_cache) :: quad
    type(shader_program) :: fractal_program
    type(shader_program) :: mandel_program
    type(shader_program) :: particle_program
    type(shader_program) :: blend_program
    integer(c_int) :: fractal_palette_texture = 0_c_int
    integer(c_int) :: scratch_fbo(2) = 0_c_int
    integer(c_int) :: scratch_tex(2) = 0_c_int
    integer(c_int) :: particle_vao = 0_c_int
    integer(c_int) :: width = 0_c_int
    integer(c_int) :: height = 0_c_int
    integer(c_int) :: fractal_resolution_uniform = -1
    integer(c_int) :: fractal_center_x_uniform = -1
    integer(c_int) :: fractal_center_y_uniform = -1
    integer(c_int) :: fractal_scale_uniform = -1
    integer(c_int) :: fractal_julia_uniform = -1
    integer(c_int) :: fractal_palette_uniform = -1
    integer(c_int) :: fractal_palette_phase_uniform = -1
    integer(c_int) :: fractal_time_uniform = -1
    integer(c_int) :: fractal_type_uniform = -1
    integer(c_int) :: fractal_iter_uniform = -1
    integer(c_int) :: fractal_orbit_uniform = -1
    integer(c_int) :: mandel_resolution_uniform = -1
    integer(c_int) :: mandel_origin_uniform = -1
    integer(c_int) :: mandel_target_uniform = -1
    integer(c_int) :: mandel_up_uniform = -1
    integer(c_int) :: mandel_type_uniform = -1
    integer(c_int) :: mandel_steps_uniform = -1
    integer(c_int) :: particle_resolution_uniform = -1
    integer(c_int) :: particle_time_uniform = -1
    integer(c_int) :: particle_progress_uniform = -1
    integer(c_int) :: particle_brightness_uniform = -1
    integer(c_int) :: blend_a_uniform = -1
    integer(c_int) :: blend_b_uniform = -1
    integer(c_int) :: blend_fade_uniform = -1
    integer(c_int) :: blend_mix_uniform = -1
    real(real64) :: paused_time = 0.0_real64
    real(real64) :: pause_started = 0.0_real64
    real(real64) :: scene_start = 0.0_real64
    real(real64) :: scrub_offset = 0.0_real64
    real(real64) :: scene_time = 0.0_real64
    logical :: paused = .false.
    type(post_settings_t) :: post_settings = post_settings_t()
  contains
    procedure :: destroy => combined_destroy
    procedure :: get_name => combined_get_name
    procedure :: get_post_settings => combined_get_post_settings
    procedure :: init => combined_init
    procedure :: render => combined_render
    procedure :: update => combined_update
  end type combined_scene_type

  character(len=*), parameter :: blend_vertex_shader = &
    "#version 330 core"//new_line("a")// &
    "const vec2 positions[3]=vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));"//new_line("a")// &
    "out vec2 uv;"//new_line("a")// &
    "void main(){ vec2 p=positions[gl_VertexID]; uv=p*0.5+0.5; gl_Position=vec4(p,0.0,1.0); }"

  character(len=*), parameter :: blend_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec2 uv; out vec4 fragColor;"//new_line("a")// &
    "uniform sampler2D u_a; uniform sampler2D u_b;"//new_line("a")// &
    "uniform float u_mix_amount; uniform float u_fade_to_black;"//new_line("a")// &
    "void main(){"//new_line("a")// &
    "  vec3 color=mix(texture(u_a,uv).rgb, texture(u_b,uv).rgb, clamp(u_mix_amount,0.0,1.0));"//new_line("a")// &
    "  color*=1.0-clamp(u_fade_to_black,0.0,1.0);"//new_line("a")// &
    "  fragColor=vec4(color,1.0);"//new_line("a")// &
    "}"

  character(len=*), parameter :: particle_vertex_shader = &
    "#version 330 core"//new_line("a")// &
    "out vec4 v_color; out float v_alpha;"//new_line("a")// &
    "uniform vec2 u_resolution; uniform float u_time; uniform float u_progress;"//new_line("a")// &
    "float hash(float x){ return fract(sin(x*91.137+13.17)*43758.5453); }"//new_line("a")// &
    "void main(){"//new_line("a")// &
    "  float id=float(gl_VertexID);"//new_line("a")// &
    "  float turn=6.2831853*(0.6180339*id+u_time*0.03);"//new_line("a")// &
    "  float seed=hash(id);"//new_line("a")// &
    "  float band=pow(fract(id/9000.0),0.65);"//new_line("a")// &
    "  float radius=mix(1.55,0.22,pow(u_progress,1.6))*mix(0.18,1.0,band);"//new_line("a")// &
    "  vec2 base=vec2(cos(turn),sin(turn))*radius;"//new_line("a")// &
    "  vec2 swirl=vec2(-base.y,base.x)*(0.12+0.35*u_progress);"//new_line("a")// &
    "  vec2 pos=base+swirl+0.08*vec2(hash(id+7.0)-0.5,hash(id+19.0)-0.5)*(1.0-u_progress);"//new_line("a")// &
    "  pos.x*=u_resolution.y/max(u_resolution.x,1.0);"//new_line("a")// &
    "  gl_Position=vec4(pos,0.0,1.0);"//new_line("a")// &
    "  gl_PointSize=mix(1.0,5.6,1.0-band)*(1.0+0.9*u_progress);"//new_line("a")// &
    "  vec3 cold=mix(vec3(0.12,0.28,0.84),vec3(0.36,0.92,1.10),seed);"//new_line("a")// &
    "  vec3 warm=mix(vec3(1.10,0.78,0.22),vec3(1.80,1.60,0.86),seed);"//new_line("a")// &
    "  v_color=vec4(mix(cold,warm,pow(u_progress,1.5)),1.0);"//new_line("a")// &
    "  v_alpha=mix(0.22,0.95,pow(u_progress,1.4));"//new_line("a")// &
    "}"

  character(len=*), parameter :: particle_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec4 v_color; in float v_alpha; out vec4 fragColor;"//new_line("a")// &
    "uniform float u_brightness;"//new_line("a")// &
    "void main(){"//new_line("a")// &
    "  vec2 p=gl_PointCoord*2.0-1.0; float r2=dot(p,p); if(r2>1.0) discard;"//new_line("a")// &
    "  float glow=exp(-3.8*r2); fragColor=vec4(v_color.rgb*u_brightness*mix(0.8,3.6,glow), glow*v_alpha);"//new_line("a")// &
    "}"

contains
  subroutine setup_combined_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(combined_scene_type :: scene)
  end subroutine setup_combined_scene

  subroutine combined_init(this)
    class(combined_scene_type), intent(inout) :: this
    character(len=:), allocatable :: fragment_source
    character(len=:), allocatable :: vertex_source
    integer(c_int), target :: vao_id

    call load_timeline_file("assets/timelines/combined.tl", this%timeline)
    call this%mandel_camera%configure("mandel_cam_pos", "mandel_cam_look")
    call this%quad%initialize()
    call this%blend_program%build(blend_vertex_shader, blend_fragment_shader, "combined blend")
    call this%particle_program%build(particle_vertex_shader, particle_fragment_shader, "combined particles")
    this%blend_a_uniform = this%blend_program%uniform("u_a")
    this%blend_b_uniform = this%blend_program%uniform("u_b")
    this%blend_fade_uniform = this%blend_program%uniform("u_fade_to_black")
    this%blend_mix_uniform = this%blend_program%uniform("u_mix_amount")
    this%particle_resolution_uniform = this%particle_program%uniform("u_resolution")
    this%particle_time_uniform = this%particle_program%uniform("u_time")
    this%particle_progress_uniform = this%particle_program%uniform("u_progress")
    this%particle_brightness_uniform = this%particle_program%uniform("u_brightness")

    vertex_source = read_text_file("assets/shaders/fractal2d.vert")
    fragment_source = read_text_file("assets/shaders/fractal2d.frag")
    call this%fractal_program%build(vertex_source, fragment_source, "combined fractal")
    this%fractal_resolution_uniform = this%fractal_program%uniform("u_resolution")
    this%fractal_center_x_uniform = this%fractal_program%uniform("u_center_x")
    this%fractal_center_y_uniform = this%fractal_program%uniform("u_center_y")
    this%fractal_scale_uniform = this%fractal_program%uniform("u_scale")
    this%fractal_julia_uniform = this%fractal_program%uniform("u_julia_c")
    this%fractal_palette_uniform = this%fractal_program%uniform("u_palette")
    this%fractal_palette_phase_uniform = this%fractal_program%uniform("u_palette_phase")
    this%fractal_time_uniform = this%fractal_program%uniform("u_time")
    this%fractal_type_uniform = this%fractal_program%uniform("u_fractal_type")
    this%fractal_iter_uniform = this%fractal_program%uniform("u_max_iter")
    this%fractal_orbit_uniform = this%fractal_program%uniform("u_orbit_trap_mode")

    vertex_source = read_text_file("assets/shaders/raymarch.vert")
    fragment_source = read_text_file("assets/shaders/raymarch.frag")
    call this%mandel_program%build(vertex_source, fragment_source, "combined mandel")
    this%mandel_resolution_uniform = this%mandel_program%uniform("u_resolution")
    this%mandel_origin_uniform = this%mandel_program%uniform("u_camera_origin")
    this%mandel_target_uniform = this%mandel_program%uniform("u_camera_target")
    this%mandel_up_uniform = this%mandel_program%uniform("u_camera_up")
    this%mandel_type_uniform = this%mandel_program%uniform("u_fractal_type")
    this%mandel_steps_uniform = this%mandel_program%uniform("u_max_steps")

    call ensure_fractal_palette(this)
    vao_id = 0_c_int
    call gl_gen_vertex_arrays(1_c_int, c_loc(vao_id))
    this%particle_vao = vao_id
    this%scene_start = runtime_elapsed()
    this%paused_time = 0.0_real64
    this%scrub_offset = 0.0_real64
    this%scene_time = 0.0_real64
  end subroutine combined_init

  subroutine combined_destroy(this)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), target :: vao_id
    integer(c_int), target :: texture_id
    integer(c_int), target :: fbo_id
    integer :: index

    call this%fractal_program%destroy()
    call this%mandel_program%destroy()
    call this%particle_program%destroy()
    call this%blend_program%destroy()
    call this%quad%destroy()
    texture_id = this%fractal_palette_texture
    if (texture_id /= 0_c_int) call gl_delete_textures(1_c_int, c_loc(texture_id))
    do index = 1, 2
      texture_id = this%scratch_tex(index)
      if (texture_id /= 0_c_int) call gl_delete_textures(1_c_int, c_loc(texture_id))
      fbo_id = this%scratch_fbo(index)
      if (fbo_id /= 0_c_int) call gl_delete_framebuffers(1_c_int, c_loc(fbo_id))
    end do
    vao_id = this%particle_vao
    if (vao_id /= 0_c_int) call gl_delete_vertex_arrays(1_c_int, c_loc(vao_id))
  end subroutine combined_destroy

  subroutine combined_get_name(this, value)
    class(combined_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "combined_showcase"
  end subroutine combined_get_name

  function combined_get_post_settings(this) result(settings)
    class(combined_scene_type), intent(in) :: this
    type(post_settings_t) :: settings

    settings = this%post_settings
  end function combined_get_post_settings

  subroutine combined_update(this, delta_seconds)
    class(combined_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds
    real(real64) :: elapsed_now
    real(real64) :: duration

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
    duration = this%timeline%get_duration()
    elapsed_now = runtime_elapsed()

    if (runtime_was_pressed(key_escape)) call runtime_request_menu()
    if (runtime_was_pressed(key_space)) then
      if (this%paused) then
        this%paused = .false.
        this%paused_time = this%paused_time + (elapsed_now - this%pause_started)
      else
        this%paused = .true.
        this%pause_started = elapsed_now
      end if
    end if
    if (runtime_was_pressed(key_r)) then
      this%scene_start = elapsed_now
      this%paused_time = 0.0_real64
      this%scrub_offset = 0.0_real64
      this%paused = .false.
    end if
    if (runtime_was_pressed(key_left)) this%scrub_offset = this%scrub_offset - 1.0_real64
    if (runtime_was_pressed(key_right)) this%scrub_offset = this%scrub_offset + 1.0_real64
    if (this%paused) then
      if (runtime_was_pressed(key_period)) this%scrub_offset = this%scrub_offset + 1.0_real64 / target_fps
    end if

    if (this%paused) then
      this%scene_time = modulo(this%pause_started - this%scene_start - this%paused_time + this%scrub_offset, duration)
    else
      this%scene_time = modulo(elapsed_now - this%scene_start - this%paused_time + this%scrub_offset, duration)
    end if
    if (this%scene_time < 0.0_real64) this%scene_time = this%scene_time + duration

    this%post_settings%bloom_strength = real(this%timeline%get_value("bloom_strength", this%scene_time, 0.9_real64))
    this%post_settings%bloom_threshold = 1.0
    this%post_settings%tone_map_mode = tone_aces
    this%post_settings%vignette_strength = real(this%timeline%get_value("vignette_strength", this%scene_time, 0.3_real64))
    this%post_settings%grain_strength = real(this%timeline%get_value("grain_strength", this%scene_time, 0.02_real64))
    this%post_settings%chromatic_ab = this%scene_time >= act3_start
  end subroutine combined_update

  subroutine combined_render(this)
    class(combined_scene_type), intent(inout) :: this
    integer :: width
    integer :: height
    integer(c_int), target :: scene_target
    real(real64) :: crossfade
    real(real64) :: fade_to_black
    real(real64) :: local_time

    call runtime_framebuffer_size(width, height)
    call ensure_targets(this, int(width, c_int), int(height, c_int))
    scene_target = 0_c_int
    call gl_get_integerv(gl_framebuffer_binding, c_loc(scene_target))

    fade_to_black = sequence_fade(this%scene_time, this%timeline%get_duration())

    if (this%scene_time < act2_start - 0.5_real64 * crossfade_span) then
      if (fade_to_black > 0.0_real64) then
        call render_fractal_pass(this, this%scratch_fbo(1), this%scene_time)
        call render_blend_pass(this, scene_target, this%scratch_tex(1), this%scratch_tex(1), 0.0_real64, fade_to_black)
      else
        call render_fractal_pass(this, scene_target, this%scene_time)
      end if
      local_time = this%scene_time
    else if (this%scene_time < act2_start + 0.5_real64 * crossfade_span) then
      crossfade = smoothstep_real( &
        act2_start - 0.5_real64 * crossfade_span, &
        act2_start + 0.5_real64 * crossfade_span, &
        this%scene_time &
      )
      call render_fractal_pass(this, this%scratch_fbo(1), min(act2_start, this%scene_time))
      call render_mandel_pass(this, this%scratch_fbo(2), act2_start + max(0.0_real64, this%scene_time - act2_start))
      call render_blend_pass(this, scene_target, this%scratch_tex(1), this%scratch_tex(2), crossfade, fade_to_black)
      local_time = this%scene_time
    else if (this%scene_time < act3_start - 0.5_real64 * crossfade_span) then
      if (fade_to_black > 0.0_real64) then
        call render_mandel_pass(this, this%scratch_fbo(1), this%scene_time)
        call render_blend_pass(this, scene_target, this%scratch_tex(1), this%scratch_tex(1), 0.0_real64, fade_to_black)
      else
        call render_mandel_pass(this, scene_target, this%scene_time)
      end if
      local_time = this%scene_time
    else if (this%scene_time < act3_start + 0.5_real64 * crossfade_span) then
      crossfade = smoothstep_real( &
        act3_start - 0.5_real64 * crossfade_span, &
        act3_start + 0.5_real64 * crossfade_span, &
        this%scene_time &
      )
      call render_mandel_pass(this, this%scratch_fbo(1), min(act3_start, this%scene_time))
      call render_particle_pass(this, this%scratch_fbo(2), act3_start + max(0.0_real64, this%scene_time - act3_start))
      call render_blend_pass(this, scene_target, this%scratch_tex(1), this%scratch_tex(2), crossfade, fade_to_black)
      local_time = this%scene_time
    else
      if (fade_to_black > 0.0_real64) then
        call render_particle_pass(this, this%scratch_fbo(1), this%scene_time)
        call render_blend_pass(this, scene_target, this%scratch_tex(1), this%scratch_tex(1), 0.0_real64, fade_to_black)
      else
        call render_particle_pass(this, scene_target, this%scene_time)
      end if
      local_time = this%scene_time
    end if

    call draw_overlay(this, width, height, local_time)
  end subroutine combined_render

  subroutine ensure_targets(this, width, height)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), intent(in), value :: width
    integer(c_int), intent(in), value :: height
    integer :: index

    if (this%width == width .and. this%height == height) return
    do index = 1, 2
      call destroy_target(this%scratch_fbo(index), this%scratch_tex(index))
      call allocate_target(this%scratch_fbo(index), this%scratch_tex(index), width, height)
    end do
    this%width = width
    this%height = height
  end subroutine ensure_targets

  subroutine render_fractal_pass(this, framebuffer, time_value)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), intent(in), value :: framebuffer
    real(real64), intent(in), value :: time_value
    real(real64) :: center_x
    real(real64) :: center_y
    real(real64) :: scale
    real(c_float) :: center_x_hi
    real(c_float) :: center_x_lo
    real(c_float) :: center_y_hi
    real(c_float) :: center_y_lo
    real(c_float) :: scale_hi
    real(c_float) :: scale_lo
    real(c_float), target :: strip(4, palette_width)
    integer :: iter_cap
    real(c_float) :: palette_phase

    center_x = this%timeline%get_value("fractal_center_x", time_value, -0.743643887_real64)
    center_y = this%timeline%get_value("fractal_center_y", time_value, 0.131825904_real64)
    scale = this%timeline%get_value("fractal_scale", time_value, 2.8_real64)
    iter_cap = min(2048, max(320, 256 + int(max(0.0_real64, -log10(max(scale, 1.0e-15_real64))) * 220.0_real64)))
    center_x_hi = real(center_x, c_float)
    center_x_lo = real(center_x - real(center_x_hi, real64), c_float)
    center_y_hi = real(center_y, c_float)
    center_y_lo = real(center_y - real(center_y_hi, real64), c_float)
    scale_hi = real(scale, c_float)
    scale_lo = real(scale - real(scale_hi, real64), c_float)
    strip = palette_rgba(:, :, 4)

    call bind_scene_target(this, framebuffer)
    call gl_active_texture(gl_texture0)
    call gl_bind_texture(gl_texture_2d, this%fractal_palette_texture)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, palette_width, 1_c_int, 0_c_int, gl_rgba, gl_float, c_loc(strip))
    call this%fractal_program%use_program()
    call gl_uniform2f(this%fractal_resolution_uniform, real(this%width, c_float), real(this%height, c_float))
    call gl_uniform2f(this%fractal_center_x_uniform, center_x_hi, center_x_lo)
    call gl_uniform2f(this%fractal_center_y_uniform, center_y_hi, center_y_lo)
    call gl_uniform2f(this%fractal_scale_uniform, scale_hi, scale_lo)
    call gl_uniform2f(this%fractal_julia_uniform, -0.78_c_float, 0.15_c_float)
    call gl_uniform1i(this%fractal_palette_uniform, 0_c_int)
    palette_phase = real(this%timeline%get_value("fractal_palette_phase", time_value, 0.08_real64), c_float)
    call gl_uniform1f(this%fractal_palette_phase_uniform, palette_phase)
    call gl_uniform1f(this%fractal_time_uniform, real(time_value, c_float))
    call gl_uniform1i(this%fractal_type_uniform, 0_c_int)
    call gl_uniform1i(this%fractal_iter_uniform, int(iter_cap, c_int))
    call gl_uniform1i(this%fractal_orbit_uniform, 1_c_int)
    call this%quad%draw()
  end subroutine render_fractal_pass

  subroutine render_mandel_pass(this, framebuffer, time_value)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), intent(in), value :: framebuffer
    real(real64), intent(in), value :: time_value
    real(real64) :: camera_position(3)
    real(real64) :: look_at(3)

    call this%mandel_camera%evaluate(this%timeline, time_value, camera_position, look_at)
    call bind_scene_target(this, framebuffer)
    call this%mandel_program%use_program()
    call gl_uniform2f(this%mandel_resolution_uniform, real(this%width, c_float), real(this%height, c_float))
    call gl_uniform3f( &
      this%mandel_origin_uniform, &
      real(camera_position(1), c_float), real(camera_position(2), c_float), real(camera_position(3), c_float) &
    )
    call gl_uniform3f( &
      this%mandel_target_uniform, &
      real(look_at(1), c_float), real(look_at(2), c_float), real(look_at(3), c_float) &
    )
    call gl_uniform3f(this%mandel_up_uniform, 0.0_c_float, 1.0_c_float, 0.0_c_float)
    call gl_uniform1i(this%mandel_type_uniform, 0_c_int)
    call gl_uniform1i(this%mandel_steps_uniform, 192_c_int)
    call this%quad%draw()
  end subroutine render_mandel_pass

  subroutine render_particle_pass(this, framebuffer, time_value)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), intent(in), value :: framebuffer
    real(real64), intent(in), value :: time_value
    real(real64) :: progress

    progress = smoothstep_real(act3_start, this%timeline%get_duration() - 3.0_real64, time_value)
    call bind_scene_target(this, framebuffer)
    call this%particle_program%use_program()
    call gl_uniform2f(this%particle_resolution_uniform, real(this%width, c_float), real(this%height, c_float))
    call gl_uniform1f(this%particle_time_uniform, real(time_value - act3_start, c_float))
    call gl_uniform1f(this%particle_progress_uniform, real(progress, c_float))
    call gl_uniform1f(this%particle_brightness_uniform, real(1.0_real64 + 1.2_real64 * progress, c_float))
    call gl_enable(gl_blend)
    call gl_enable(gl_program_point_size)
    call gl_blend_func(gl_src_alpha, gl_one)
    call gl_bind_vertex_array(this%particle_vao)
    call gl_draw_arrays(gl_points, 0_c_int, 180000_c_int)
    call gl_bind_vertex_array(0_c_int)
    call gl_disable(gl_program_point_size)
    call gl_disable(gl_blend)
  end subroutine render_particle_pass

  subroutine render_blend_pass(this, framebuffer, texture_a, texture_b, mix_amount, fade_to_black)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), intent(in), value :: framebuffer
    integer(c_int), intent(in), value :: texture_a
    integer(c_int), intent(in), value :: texture_b
    real(real64), intent(in), value :: mix_amount
    real(real64), intent(in), value :: fade_to_black

    call bind_scene_target(this, framebuffer)
    call this%blend_program%use_program()
    call gl_active_texture(gl_texture0)
    call gl_bind_texture(gl_texture_2d, texture_a)
    call gl_uniform1i(this%blend_a_uniform, 0_c_int)
    call gl_active_texture(gl_texture1)
    call gl_bind_texture(gl_texture_2d, texture_b)
    call gl_uniform1i(this%blend_b_uniform, 1_c_int)
    call gl_uniform1f(this%blend_mix_uniform, real(mix_amount, c_float))
    call gl_uniform1f(this%blend_fade_uniform, real(fade_to_black, c_float))
    call this%quad%draw()
  end subroutine render_blend_pass

  subroutine bind_scene_target(this, framebuffer)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), intent(in), value :: framebuffer

    call gl_bind_framebuffer(gl_framebuffer, framebuffer)
    call gl_viewport(0_c_int, 0_c_int, this%width, this%height)
    call gl_clear_color(0.0_c_float, 0.0_c_float, 0.0_c_float, 1.0_c_float)
    call gl_clear(gl_color_buffer_bit)
  end subroutine bind_scene_target

  subroutine draw_overlay(this, width, height, time_value)
    class(combined_scene_type), intent(inout) :: this
    integer, intent(in), value :: width
    integer, intent(in), value :: height
    real(real64), intent(in), value :: time_value
    character(len=64) :: line
    integer :: bar_w
    integer :: playhead_x

    if (runtime_is_offline()) return
    call runtime_text_begin_frame()
    if (time_value < act2_start) then
      line = "ACT I  BIRTH"
    else if (time_value < act3_start) then
      line = "ACT II  ASCENT"
    else
      line = "ACT III  LIGHTWELL"
    end if
    call runtime_draw_text(line, 28, 28, 3, [0.95, 0.84, 0.48, 1.0])
    if (this%paused) then
      call runtime_draw_text("PAUSED", 28, 64, 2, [0.82, 0.87, 0.92, 1.0])
    end if
    call runtime_draw_text("LEFT/RIGHT SEEK  SPACE PAUSE  . STEP  R RESTART  ESC MENU", &
      max(20, width - runtime_measure_text("LEFT/RIGHT SEEK  SPACE PAUSE  . STEP  R RESTART  ESC MENU", 2) - 24), &
      height - 44, 2, [0.60, 0.66, 0.74, 1.0])

    bar_w = max(220, width - 120)
    playhead_x = 60 + int((time_value / max(1.0_real64, this%timeline%get_duration())) * real(bar_w - 4, real64))
    call runtime_draw_text(repeat("-", max(12, bar_w / 12)), 60, height - 84, 1, [0.45, 0.48, 0.54, 1.0])
    call runtime_draw_text("|", playhead_x, height - 90, 2, [0.98, 0.88, 0.60, 1.0])
  end subroutine draw_overlay

  subroutine ensure_fractal_palette(this)
    class(combined_scene_type), intent(inout) :: this
    integer(c_int), target :: texture_id
    real(c_float), target :: strip(4, palette_width)

    if (this%fractal_palette_texture /= 0_c_int) return
    texture_id = 0_c_int
    strip = palette_rgba(:, :, 1)
    call gl_gen_textures(1_c_int, c_loc(texture_id))
    this%fractal_palette_texture = texture_id
    call gl_bind_texture(gl_texture_2d, this%fractal_palette_texture)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_min_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_mag_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, palette_width, 1_c_int, 0_c_int, gl_rgba, gl_float, c_loc(strip))
    call gl_bind_texture(gl_texture_2d, 0_c_int)
  end subroutine ensure_fractal_palette

  subroutine destroy_target(fbo, texture)
    integer(c_int), intent(inout) :: fbo
    integer(c_int), intent(inout) :: texture
    integer(c_int), target :: fbo_id
    integer(c_int), target :: tex_id

    tex_id = texture
    if (tex_id /= 0_c_int) call gl_delete_textures(1_c_int, c_loc(tex_id))
    fbo_id = fbo
    if (fbo_id /= 0_c_int) call gl_delete_framebuffers(1_c_int, c_loc(fbo_id))
    fbo = 0_c_int
    texture = 0_c_int
  end subroutine destroy_target

  subroutine allocate_target(fbo, texture, width, height)
    integer(c_int), intent(inout) :: fbo
    integer(c_int), intent(inout) :: texture
    integer(c_int), intent(in), value :: width
    integer(c_int), intent(in), value :: height
    integer(c_int), target :: fbo_id
    integer(c_int), target :: tex_id

    fbo_id = 0_c_int
    tex_id = 0_c_int
    call gl_gen_framebuffers(1_c_int, c_loc(fbo_id))
    call gl_gen_textures(1_c_int, c_loc(tex_id))
    fbo = fbo_id
    texture = tex_id
    call gl_bind_texture(gl_texture_2d, texture)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_min_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_mag_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, width, height, 0_c_int, gl_rgba, gl_float, c_null_ptr)
    call gl_bind_framebuffer(gl_framebuffer, fbo)
    call gl_framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, texture, 0_c_int)
    if (gl_check_framebuffer_status(gl_framebuffer) /= gl_framebuffer_complete) error stop "Combined FBO incomplete."
    call gl_bind_framebuffer(gl_framebuffer, 0_c_int)
  end subroutine allocate_target

  real(real64) function smoothstep_real(edge0, edge1, x) result(value)
    real(real64), intent(in), value :: edge0
    real(real64), intent(in), value :: edge1
    real(real64), intent(in), value :: x
    real(real64) :: t

    t = (x - edge0) / max(1.0e-12_real64, edge1 - edge0)
    t = min(1.0_real64, max(0.0_real64, t))
    value = t * t * (3.0_real64 - 2.0_real64 * t)
  end function smoothstep_real

  real(real64) function sequence_fade(time_value, duration) result(value)
    real(real64), intent(in), value :: time_value
    real(real64), intent(in), value :: duration
    real(real64) :: fade_in
    real(real64) :: fade_out

    fade_in = 1.0_real64 - smoothstep_real(0.0_real64, 1.5_real64, time_value)
    fade_out = smoothstep_real(max(0.0_real64, duration - 3.0_real64), duration, time_value)
    value = max(fade_in, fade_out)
  end function sequence_fade
end module scene_combined
