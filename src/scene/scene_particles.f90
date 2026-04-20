module scene_particles
  use, intrinsic :: iso_c_binding, only: c_double, c_float, c_int, c_intptr_t, c_loc, c_null_ptr, c_ptr
  use app_runtime, only: runtime_draw_text, runtime_framebuffer_size, runtime_measure_text, runtime_mouse_delta
  use app_runtime, only: runtime_mouse_is_down, runtime_request_menu, runtime_scroll_delta, runtime_text_begin_frame
  use app_runtime, only: runtime_is_offline, runtime_was_pressed
  use core_kinds, only: real64
  use core_text_file, only: read_text_file
  use gl_loader, only: gl_active_texture, gl_array_buffer, gl_bind_buffer, gl_bind_buffer_base, gl_bind_texture
  use gl_loader, only: gl_bind_vertex_array, gl_blend, gl_blend_func, gl_buffer_data, gl_clamp_to_edge
  use gl_loader, only: gl_delete_buffers, gl_delete_textures, gl_delete_vertex_arrays, gl_disable, gl_dispatch_compute
  use gl_loader, only: gl_draw_arrays, gl_dynamic_draw, gl_enable, gl_enable_vertex_attrib_array, gl_float, gl_gen_buffers
  use gl_loader, only: gl_gen_textures, gl_gen_vertex_arrays, gl_linear, gl_memory_barrier, gl_one
  use gl_loader, only: gl_points, gl_program_point_size, gl_rgba, gl_rgba16f, gl_shader_storage_barrier_bit
  use gl_loader, only: gl_shader_storage_buffer, gl_src_alpha, gl_tex_image_2d, gl_tex_parameteri, gl_texture0
  use gl_loader, only: gl_texture_2d, gl_texture_mag_filter, gl_texture_min_filter, gl_texture_wrap_s, gl_texture_wrap_t
  use gl_loader, only: gl_uniform1f, gl_uniform1i, gl_uniform2f, gl_uniform3f, gl_use_program, gl_vertex_attrib_pointer
  use platform_input, only: key_1, key_2, key_3, key_escape, key_h, key_r, key_space, mouse_button_left
  use render_shader, only: shader_program
  use scene_base, only: post_settings_t, scene_type, tone_aces
  implicit none (type, external)
  private

  integer, parameter :: floats_per_particle = 12
  integer, parameter :: particle_stride_bytes = 48
  integer, parameter :: particle_count_galaxy = 320000
  integer, parameter :: particle_count_vortex = 520000
  integer, parameter :: particle_count_nebula = 900000
  integer, parameter :: preset_galaxy = 1
  integer, parameter :: preset_vortex = 2
  integer, parameter :: preset_nebula = 3

  public :: particle_scene_type
  public :: setup_particle_scene

  type, extends(scene_type) :: particle_scene_type
    type(shader_program) :: compute_program
    type(shader_program) :: draw_program
    integer(c_int) :: palette_texture = 0_c_int
    integer(c_int) :: particle_buffer = 0_c_int
    integer(c_int) :: vao = 0_c_int
    integer(c_int) :: compute_delta_uniform = -1
    integer(c_int) :: compute_drag_uniform = -1
    integer(c_int) :: compute_lifetime_uniform = -1
    integer(c_int) :: compute_outer_radius_uniform = -1
    integer(c_int) :: compute_particle_count_uniform = -1
    integer(c_int) :: compute_preset_uniform = -1
    integer(c_int) :: compute_seed_uniform = -1
    integer(c_int) :: draw_camera_origin_uniform = -1
    integer(c_int) :: draw_camera_target_uniform = -1
    integer(c_int) :: draw_camera_up_uniform = -1
    integer(c_int) :: draw_lifetime_uniform = -1
    integer(c_int) :: draw_palette_uniform = -1
    integer(c_int) :: draw_resolution_uniform = -1
    logical :: paused = .false.
    logical :: show_hud = .true.
    integer :: particle_count = 0
    integer :: preset = preset_galaxy
    integer :: reseed_serial = 0
    real(real64) :: camera_pitch = 0.22_real64
    real(real64) :: camera_radius = 5.8_real64
    real(real64) :: camera_yaw = 0.4_real64
    real(real64) :: last_render_ms = 0.0_real64
    real(real64) :: last_step_ms = 0.0_real64
  contains
    procedure :: destroy => particle_destroy
    procedure :: get_name => particle_get_name
    procedure :: get_post_settings => particle_get_post_settings
    procedure :: init => particle_init
    procedure :: render => particle_render
    procedure :: update => particle_update
  end type particle_scene_type

contains
  subroutine setup_particle_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(particle_scene_type :: scene)
  end subroutine setup_particle_scene

  subroutine particle_init(this)
    class(particle_scene_type), intent(inout) :: this
    character(len=:), allocatable :: compute_source
    character(len=:), allocatable :: draw_fragment_source
    character(len=:), allocatable :: draw_vertex_source
    integer(c_int), target :: buffer_id
    integer(c_int), target :: vao_id

    compute_source = read_text_file("assets/shaders/particles_step.comp")
    draw_vertex_source = read_text_file("assets/shaders/particles_draw.vert")
    draw_fragment_source = read_text_file("assets/shaders/particles_draw.frag")

    call this%compute_program%build_compute(compute_source, "particle galaxy")
    call this%draw_program%build(draw_vertex_source, draw_fragment_source, "particle draw")

    this%compute_delta_uniform = this%compute_program%uniform("u_delta_seconds")
    this%compute_drag_uniform = this%compute_program%uniform("u_drag")
    this%compute_lifetime_uniform = this%compute_program%uniform("u_lifetime")
    this%compute_outer_radius_uniform = this%compute_program%uniform("u_outer_radius")
    this%compute_particle_count_uniform = this%compute_program%uniform("u_particle_count")
    this%compute_preset_uniform = this%compute_program%uniform("u_preset_mix")
    this%compute_seed_uniform = this%compute_program%uniform("u_seed")

    this%draw_camera_origin_uniform = this%draw_program%uniform("u_camera_origin")
    this%draw_camera_target_uniform = this%draw_program%uniform("u_camera_target")
    this%draw_camera_up_uniform = this%draw_program%uniform("u_camera_up")
    this%draw_lifetime_uniform = this%draw_program%uniform("u_lifetime")
    this%draw_palette_uniform = this%draw_program%uniform("u_palette")
    this%draw_resolution_uniform = this%draw_program%uniform("u_resolution")

    call allocate_palette_texture(this)

    buffer_id = 0_c_int
    vao_id = 0_c_int
    call gl_gen_buffers(1_c_int, c_loc(buffer_id))
    call gl_gen_vertex_arrays(1_c_int, c_loc(vao_id))
    this%particle_buffer = buffer_id
    this%vao = vao_id

    call gl_bind_vertex_array(this%vao)
    call gl_bind_buffer(gl_array_buffer, this%particle_buffer)
    call gl_enable_vertex_attrib_array(0_c_int)
    call gl_vertex_attrib_pointer(0_c_int, 4_c_int, gl_float, 0_c_int, particle_stride_bytes, c_null_ptr)
    call gl_enable_vertex_attrib_array(1_c_int)
    call gl_vertex_attrib_pointer(1_c_int, 4_c_int, gl_float, 0_c_int, particle_stride_bytes, c_ptr_from_offset(32_c_intptr_t))
    call gl_bind_vertex_array(0_c_int)
    call gl_bind_buffer(gl_array_buffer, 0_c_int)

    call apply_preset(this, preset_galaxy)
  end subroutine particle_init

  subroutine particle_destroy(this)
    class(particle_scene_type), intent(inout) :: this
    integer(c_int), target :: buffer_id
    integer(c_int), target :: texture_id
    integer(c_int), target :: vao_id

    buffer_id = this%particle_buffer
    vao_id = this%vao
    texture_id = this%palette_texture
    if (buffer_id /= 0_c_int) call gl_delete_buffers(1_c_int, c_loc(buffer_id))
    if (vao_id /= 0_c_int) call gl_delete_vertex_arrays(1_c_int, c_loc(vao_id))
    if (texture_id /= 0_c_int) call gl_delete_textures(1_c_int, c_loc(texture_id))
    call this%compute_program%destroy()
    call this%draw_program%destroy()
    this%particle_buffer = 0_c_int
    this%vao = 0_c_int
    this%palette_texture = 0_c_int
  end subroutine particle_destroy

  subroutine particle_get_name(this, value)
    class(particle_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "particle_galaxy"
  end subroutine particle_get_name

  function particle_get_post_settings(this) result(settings)
    class(particle_scene_type), intent(in) :: this
    type(post_settings_t) :: settings

    if (.false.) print *, same_type_as(this, this)
    settings%bloom_strength = 1.6
    settings%bloom_threshold = 1.0
    settings%tone_map_mode = tone_aces
    settings%vignette_strength = 0.25
    settings%grain_strength = 0.03
    settings%chromatic_ab = .true.
  end function particle_get_post_settings

  subroutine particle_update(this, delta_seconds)
    class(particle_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds
    real(c_double) :: mouse_dx
    real(c_double) :: mouse_dy
    real(c_double) :: scroll_dx
    real(c_double) :: scroll_dy

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
    if (runtime_was_pressed(key_escape)) call runtime_request_menu()
    if (runtime_was_pressed(key_h)) this%show_hud = .not. this%show_hud
    if (runtime_was_pressed(key_space)) this%paused = .not. this%paused
    if (runtime_was_pressed(key_r)) call reseed_particles(this)
    if (runtime_was_pressed(key_1)) call apply_preset(this, preset_galaxy)
    if (runtime_was_pressed(key_2)) call apply_preset(this, preset_vortex)
    if (runtime_was_pressed(key_3)) call apply_preset(this, preset_nebula)

    call runtime_mouse_delta(mouse_dx, mouse_dy)
    if (runtime_mouse_is_down(mouse_button_left)) then
      this%camera_yaw = this%camera_yaw - real(mouse_dx, real64) * 0.008_real64
      this%camera_pitch = min(1.1_real64, max(-0.8_real64, this%camera_pitch - real(mouse_dy, real64) * 0.006_real64))
    end if

    call runtime_scroll_delta(scroll_dx, scroll_dy)
    if (abs(scroll_dx) > 0.0_c_double .or. abs(scroll_dy) > 0.0_c_double) then
      this%camera_radius = min(11.0_real64, max(2.4_real64, this%camera_radius * exp(-0.08_real64 * real(scroll_dy, real64))))
    end if

    if (.not. this%paused) call step_particles(this, min(delta_seconds, 1.0_real64 / 30.0_real64))
  end subroutine particle_update

  subroutine particle_render(this)
    class(particle_scene_type), intent(inout) :: this
    character(len=64) :: count_line
    character(len=64) :: paused_line
    character(len=64) :: preset_line
    character(len=64) :: render_line
    character(len=64) :: step_line
    integer :: clock_rate
    integer :: finish_ticks
    integer :: height
    integer :: start_ticks
    integer :: width
    real(real64) :: camera_x
    real(real64) :: camera_y
    real(real64) :: camera_z

    call runtime_framebuffer_size(width, height)
    camera_x = this%camera_radius * cos(this%camera_pitch) * sin(this%camera_yaw)
    camera_y = this%camera_radius * sin(this%camera_pitch)
    camera_z = this%camera_radius * cos(this%camera_pitch) * cos(this%camera_yaw)

    call system_clock(start_ticks, clock_rate)
    call gl_enable(gl_blend)
    call gl_enable(gl_program_point_size)
    call gl_blend_func(gl_src_alpha, gl_one)
    call this%draw_program%use_program()
    call gl_uniform3f(this%draw_camera_origin_uniform, real(camera_x, c_float), real(camera_y, c_float), real(camera_z, c_float))
    call gl_uniform3f(this%draw_camera_target_uniform, 0.0_c_float, 0.0_c_float, 0.0_c_float)
    call gl_uniform3f(this%draw_camera_up_uniform, 0.0_c_float, 1.0_c_float, 0.0_c_float)
    call gl_uniform1f(this%draw_lifetime_uniform, real(lifetime_for_preset(this%preset), c_float))
    call gl_uniform2f(this%draw_resolution_uniform, real(width, c_float), real(height, c_float))
    call gl_active_texture(gl_texture0)
    call gl_bind_texture(gl_texture_2d, this%palette_texture)
    call gl_uniform1i(this%draw_palette_uniform, 0_c_int)
    call gl_bind_vertex_array(this%vao)
    call gl_draw_arrays(gl_points, 0_c_int, int(this%particle_count, c_int))
    call gl_bind_vertex_array(0_c_int)
    call gl_disable(gl_program_point_size)
    call system_clock(finish_ticks, clock_rate)
    this%last_render_ms = 1000.0_real64 * real(finish_ticks - start_ticks, real64) / real(max(1, clock_rate), real64)

    if (runtime_is_offline()) return
    if (.not. this%show_hud) return
    call runtime_text_begin_frame()
    write (count_line, '(a,i0)') "COUNT: ", this%particle_count
    write (step_line, '(a,f6.3,a)') "SIM MS: ", this%last_step_ms, ""
    write (render_line, '(a,f6.3,a)') "DRAW MS: ", this%last_render_ms, ""
    write (preset_line, '(a,a)') "PRESET: ", trim(preset_name(this%preset))
    if (this%paused) then
      paused_line = "PAUSED: YES"
    else
      paused_line = "PAUSED: NO"
    end if
    call runtime_draw_text(count_line, 28, height - 172, 2, [0.96, 0.88, 0.58, 1.0])
    call runtime_draw_text(step_line, 28, height - 140, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(render_line, 28, height - 108, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(preset_line, 28, height - 76, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(paused_line, 28, height - 44, 2, [0.62, 0.67, 0.75, 1.0])
    call runtime_draw_text("SPACE PAUSE  R RESEED  1/2/3 PRESETS  DRAG ORBIT  WHEEL DOLLY  ESC MENU", &
      max(24, width - runtime_measure_text("SPACE PAUSE  R RESEED  1/2/3 PRESETS  DRAG ORBIT  WHEEL DOLLY  ESC MENU", 2) - 24), &
      height - 44, 2, [0.62, 0.67, 0.75, 1.0])
  end subroutine particle_render

  subroutine step_particles(this, delta_seconds)
    class(particle_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds
    integer :: clock_rate
    integer :: finish_ticks
    integer :: start_ticks

    call system_clock(start_ticks, clock_rate)
    call this%compute_program%use_program()
    call gl_bind_buffer_base(gl_shader_storage_buffer, 0_c_int, this%particle_buffer)
    call gl_uniform1f(this%compute_delta_uniform, real(delta_seconds, c_float))
    call gl_uniform1f(this%compute_drag_uniform, real(drag_for_preset(this%preset), c_float))
    call gl_uniform1f(this%compute_lifetime_uniform, real(lifetime_for_preset(this%preset), c_float))
    call gl_uniform1f(this%compute_outer_radius_uniform, real(outer_radius_for_preset(this%preset), c_float))
    call gl_uniform1f(this%compute_preset_uniform, real(this%preset - 1, c_float))
    call gl_uniform1f(this%compute_seed_uniform, real(this%reseed_serial, c_float))
    call gl_uniform1i(this%compute_particle_count_uniform, int(this%particle_count, c_int))
    call gl_dispatch_compute(int((this%particle_count + 255) / 256, c_int), 1_c_int, 1_c_int)
    call gl_memory_barrier(gl_shader_storage_barrier_bit)
    call system_clock(finish_ticks, clock_rate)
    this%last_step_ms = 1000.0_real64 * real(finish_ticks - start_ticks, real64) / real(max(1, clock_rate), real64)
  end subroutine step_particles

  subroutine apply_preset(this, preset)
    class(particle_scene_type), intent(inout) :: this
    integer, intent(in), value :: preset

    this%preset = preset
    select case (preset)
    case (preset_vortex)
      this%particle_count = particle_count_vortex
    case (preset_nebula)
      this%particle_count = particle_count_nebula
    case default
      this%particle_count = particle_count_galaxy
    end select
    call upload_palette(this)
    call reseed_particles(this)
  end subroutine apply_preset

  subroutine reseed_particles(this)
    class(particle_scene_type), intent(inout) :: this
    real(c_float), allocatable, target :: data(:)
    integer :: i
    integer :: offset
    real(real64) :: angle
    real(real64) :: height
    real(real64) :: ring

    this%reseed_serial = this%reseed_serial + 1
    allocate(data(floats_per_particle * this%particle_count))
    do i = 0, this%particle_count - 1
      angle = modulo(real(i, real64) * 0.61803398875_real64 * 6.28318530718_real64, 6.28318530718_real64)
      ring = 0.45_real64 + 0.55_real64 * modulo(real(i, real64) * 0.38196601125_real64, 1.0_real64)
      height = (modulo(real(i, real64) * 0.17320508075_real64, 1.0_real64) - 0.5_real64) * &
        merge(0.40_real64, 0.12_real64, this%preset == preset_nebula)
      offset = i * floats_per_particle
      data(offset + 1) = real(cos(angle) * outer_radius_for_preset(this%preset) * ring, c_float)
      data(offset + 2) = real(height, c_float)
      data(offset + 3) = real(sin(angle) * outer_radius_for_preset(this%preset) * ring, c_float)
      data(offset + 4) = 0.0_c_float
      data(offset + 5) = real(-sin(angle) * tangential_for_preset(this%preset), c_float)
      data(offset + 6) = real(height * 0.05_real64, c_float)
      data(offset + 7) = real(cos(angle) * tangential_for_preset(this%preset), c_float)
      data(offset + 8) = 1.0_c_float
      data(offset + 9) = 1.0_c_float
      data(offset + 10) = 1.0_c_float
      data(offset + 11) = 1.0_c_float
      data(offset + 12) = 0.0_c_float
    end do

    call gl_bind_buffer(gl_shader_storage_buffer, this%particle_buffer)
    call gl_buffer_data(gl_shader_storage_buffer, int(size(data) * 4, c_int), c_loc(data), gl_dynamic_draw)
    call gl_bind_buffer(gl_shader_storage_buffer, 0_c_int)
    deallocate(data)
  end subroutine reseed_particles

  subroutine allocate_palette_texture(this)
    class(particle_scene_type), intent(inout) :: this
    integer(c_int), target :: texture_id

    texture_id = 0_c_int
    call gl_gen_textures(1_c_int, c_loc(texture_id))
    this%palette_texture = texture_id
    call gl_bind_texture(gl_texture_2d, this%palette_texture)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_min_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_mag_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
    call gl_bind_texture(gl_texture_2d, 0_c_int)
  end subroutine allocate_palette_texture

  subroutine upload_palette(this)
    class(particle_scene_type), intent(inout) :: this
    real(c_float), target :: palette(4, 256)
    integer :: i
    real(real64) :: t

    do i = 1, 256
      t = real(i - 1, real64) / 255.0_real64
      palette(:, i) = palette_color(this%preset, t)
    end do
    call gl_bind_texture(gl_texture_2d, this%palette_texture)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, 256_c_int, 1_c_int, 0_c_int, gl_rgba, gl_float, c_loc(palette))
    call gl_bind_texture(gl_texture_2d, 0_c_int)
  end subroutine upload_palette

  function palette_color(preset, t) result(color)
    integer, intent(in), value :: preset
    real(real64), intent(in), value :: t
    real(c_float) :: color(4)
    real(real64) :: r
    real(real64) :: g
    real(real64) :: b

    select case (preset)
    case (preset_vortex)
      r = 0.18_real64 + 0.80_real64 * t
      g = 0.04_real64 + 0.44_real64 * t + 0.12_real64 * sin(3.14159_real64 * t)
      b = 0.03_real64 + 0.26_real64 * (1.0_real64 - t) + 0.18_real64 * t
    case (preset_nebula)
      r = 0.08_real64 + 0.68_real64 * t
      g = 0.30_real64 + 0.26_real64 * (1.0_real64 - t) + 0.10_real64 * sin(6.28318_real64 * t)
      b = 0.42_real64 + 0.52_real64 * t
    case default
      r = 0.08_real64 + 0.96_real64 * t
      g = 0.42_real64 + 0.42_real64 * (1.0_real64 - t * 0.35_real64)
      b = 0.22_real64 + 0.72_real64 * t
    end select
    color = [real(r, c_float), real(g, c_float), real(b, c_float), 1.0_c_float]
  end function palette_color

  real(real64) function drag_for_preset(preset) result(value)
    integer, intent(in), value :: preset

    select case (preset)
    case (preset_vortex)
      value = 0.06_real64
    case (preset_nebula)
      value = 0.02_real64
    case default
      value = 0.04_real64
    end select
  end function drag_for_preset

  real(real64) function lifetime_for_preset(preset) result(value)
    integer, intent(in), value :: preset

    select case (preset)
    case (preset_vortex)
      value = 14.0_real64
    case (preset_nebula)
      value = 22.0_real64
    case default
      value = 18.0_real64
    end select
  end function lifetime_for_preset

  real(real64) function outer_radius_for_preset(preset) result(value)
    integer, intent(in), value :: preset

    select case (preset)
    case (preset_vortex)
      value = 4.8_real64
    case (preset_nebula)
      value = 7.0_real64
    case default
      value = 5.8_real64
    end select
  end function outer_radius_for_preset

  real(real64) function tangential_for_preset(preset) result(value)
    integer, intent(in), value :: preset

    select case (preset)
    case (preset_vortex)
      value = 2.8_real64
    case (preset_nebula)
      value = 1.4_real64
    case default
      value = 2.1_real64
    end select
  end function tangential_for_preset

  character(len=16) function preset_name(preset) result(name)
    integer, intent(in), value :: preset

    select case (preset)
    case (preset_vortex)
      name = "vortex"
    case (preset_nebula)
      name = "nebula"
    case default
      name = "galaxy"
    end select
  end function preset_name

  function c_ptr_from_offset(offset_bytes) result(pointer)
    integer(c_intptr_t), intent(in), value :: offset_bytes
    type(c_ptr) :: pointer

    pointer = transfer(offset_bytes, c_null_ptr)
  end function c_ptr_from_offset
end module scene_particles
