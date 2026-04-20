module scene_mandelbulb
  use, intrinsic :: iso_c_binding, only: c_double, c_float, c_int
  use app_runtime, only: runtime_draw_text, runtime_elapsed, runtime_framebuffer_size, runtime_measure_text
  use app_runtime, only: runtime_mouse_delta, runtime_mouse_is_down, runtime_request_menu, runtime_scroll_delta
  use app_runtime, only: runtime_is_offline, runtime_text_begin_frame, runtime_was_pressed
  use core_kinds, only: real64
  use core_text_file, only: read_text_file
  use gl_loader, only: gl_uniform1i, gl_uniform2f, gl_uniform3f
  use platform_input, only: key_1, key_2, key_3, key_escape, key_f, key_h, key_r, key_v, mouse_button_left
  use render_fullscreen_quad, only: fullscreen_quad_cache
  use render_shader, only: shader_program
  use scene_base, only: post_settings_t, scene_type, tone_aces
  implicit none (type, external)
  private

  integer, parameter :: fractal_mandelbulb = 0
  integer, parameter :: fractal_menger = 1
  integer, parameter :: preset_draft = 1
  integer, parameter :: preset_normal = 2
  integer, parameter :: preset_heavy = 3
  integer, parameter :: mandelbulb_variant_classic = 0
  integer, parameter :: mandelbulb_variant_cathedral = 1
  integer, parameter :: mandelbulb_variant_nebula = 2
  integer, parameter :: mandelbulb_variant_count = 3

  public :: mandelbulb_scene_type
  public :: setup_mandelbulb_scene

  type, extends(scene_type) :: mandelbulb_scene_type
    type(fullscreen_quad_cache) :: quad
    type(shader_program) :: program
    integer(c_int) :: camera_origin_uniform = -1
    integer(c_int) :: camera_target_uniform = -1
    integer(c_int) :: camera_up_uniform = -1
    integer(c_int) :: fractal_uniform = -1
    integer(c_int) :: max_steps_uniform = -1
    integer(c_int) :: resolution_uniform = -1
    integer(c_int) :: variant_uniform = -1
    integer :: fractal_kind = fractal_mandelbulb
    integer :: mandelbulb_variant = mandelbulb_variant_cathedral
    integer :: preset = preset_normal
    logical :: auto_orbit = .true.
    logical :: show_hud = .true.
    real(real64) :: idle_seconds = 0.0_real64
    real(real64) :: orbit_pitch = 0.18_real64
    real(real64) :: orbit_radius = 4.6_real64
    real(real64) :: orbit_yaw = 0.0_real64
    real(real64) :: target_x = 0.0_real64
    real(real64) :: target_y = 0.1_real64
    real(real64) :: target_z = 0.0_real64
  contains
    procedure :: destroy => mandelbulb_destroy
    procedure :: get_name => mandelbulb_get_name
    procedure :: get_post_settings => mandelbulb_get_post_settings
    procedure :: init => mandelbulb_init
    procedure :: render => mandelbulb_render
    procedure :: update => mandelbulb_update
  end type mandelbulb_scene_type

contains
  subroutine setup_mandelbulb_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(mandelbulb_scene_type :: scene)
  end subroutine setup_mandelbulb_scene

  subroutine mandelbulb_init(this)
    class(mandelbulb_scene_type), intent(inout) :: this
    character(len=:), allocatable :: fragment_source
    character(len=:), allocatable :: vertex_source

    call this%quad%initialize()
    vertex_source = read_text_file("assets/shaders/raymarch.vert")
    fragment_source = read_text_file("assets/shaders/raymarch.frag")
    call this%program%build(vertex_source, fragment_source, "mandelbulb stage h")
    this%resolution_uniform = this%program%uniform("u_resolution")
    this%camera_origin_uniform = this%program%uniform("u_camera_origin")
    this%camera_target_uniform = this%program%uniform("u_camera_target")
    this%camera_up_uniform = this%program%uniform("u_camera_up")
    this%fractal_uniform = this%program%uniform("u_fractal_type")
    this%max_steps_uniform = this%program%uniform("u_max_steps")
    this%variant_uniform = this%program%uniform("u_variant")
    call reset_camera(this)
  end subroutine mandelbulb_init

  subroutine mandelbulb_destroy(this)
    class(mandelbulb_scene_type), intent(inout) :: this

    call this%program%destroy()
    call this%quad%destroy()
  end subroutine mandelbulb_destroy

  subroutine mandelbulb_get_name(this, value)
    class(mandelbulb_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "mandelbulb_cathedral"
  end subroutine mandelbulb_get_name

  function mandelbulb_get_post_settings(this) result(settings)
    class(mandelbulb_scene_type), intent(in) :: this
    type(post_settings_t) :: settings

    if (.false.) print *, same_type_as(this, this)
    settings%bloom_strength = 1.1
    settings%bloom_threshold = 1.0
    settings%tone_map_mode = tone_aces
    settings%vignette_strength = 0.4
    settings%grain_strength = 0.02
  end function mandelbulb_get_post_settings

  subroutine mandelbulb_update(this, delta_seconds)
    class(mandelbulb_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds
    real(c_double) :: mouse_dx
    real(c_double) :: mouse_dy
    real(c_double) :: scroll_dx
    real(c_double) :: scroll_dy
    logical :: activity

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
    activity = .false.

    if (runtime_was_pressed(key_escape)) call runtime_request_menu()
    if (runtime_was_pressed(key_f)) then
      this%fractal_kind = 1 - this%fractal_kind
      activity = .true.
    end if
    if (runtime_was_pressed(key_h)) then
      this%show_hud = .not. this%show_hud
      activity = .true.
    end if
    if (runtime_was_pressed(key_v)) then
      this%mandelbulb_variant = modulo(this%mandelbulb_variant + 1, mandelbulb_variant_count)
      activity = .true.
    end if
    if (runtime_was_pressed(key_r)) then
      call reset_camera(this)
      activity = .true.
    end if
    if (runtime_was_pressed(key_1)) then
      this%preset = preset_draft
      activity = .true.
    end if
    if (runtime_was_pressed(key_2)) then
      this%preset = preset_normal
      activity = .true.
    end if
    if (runtime_was_pressed(key_3)) then
      this%preset = preset_heavy
      activity = .true.
    end if

    call runtime_scroll_delta(scroll_dx, scroll_dy)
    if (abs(scroll_dx) > 0.0_c_double .or. abs(scroll_dy) > 0.0_c_double) then
      this%orbit_radius = min(9.0_real64, max(2.2_real64, this%orbit_radius * exp(-0.10_real64 * real(scroll_dy, real64))))
      activity = .true.
    end if

    call runtime_mouse_delta(mouse_dx, mouse_dy)
    if (runtime_mouse_is_down(mouse_button_left)) then
      if (abs(mouse_dx) > 0.0_c_double .or. abs(mouse_dy) > 0.0_c_double) then
        this%orbit_yaw = this%orbit_yaw - real(mouse_dx, real64) * 0.008_real64
        this%orbit_pitch = min(1.1_real64, max(-0.7_real64, this%orbit_pitch - real(mouse_dy, real64) * 0.006_real64))
        this%auto_orbit = .false.
        activity = .true.
      end if
    end if

    if (activity) then
      this%idle_seconds = 0.0_real64
    else
      this%idle_seconds = this%idle_seconds + delta_seconds
      if (this%idle_seconds >= 5.0_real64) this%auto_orbit = .true.
    end if

    if (this%auto_orbit) then
      this%orbit_yaw = this%orbit_yaw + delta_seconds * 0.32_real64
      this%orbit_pitch = 0.14_real64 + 0.08_real64 * sin(runtime_elapsed() * 0.42_real64)
    end if
  end subroutine mandelbulb_update

  subroutine mandelbulb_render(this)
    class(mandelbulb_scene_type), intent(inout) :: this
    character(len=*), parameter :: controls_text = &
      "F TOGGLE  V VARIANT  1/2/3 QUALITY  DRAG ORBIT  WHEEL RADIUS  R RESET  ESC MENU"
    character(len=64) :: fractal_line
    character(len=64) :: orbit_line
    character(len=64) :: preset_line
    character(len=64) :: radius_line
    character(len=64) :: variant_line
    integer :: height
    integer :: width
    real(real64) :: camera_x
    real(real64) :: camera_y
    real(real64) :: camera_z

    call runtime_framebuffer_size(width, height)
    camera_x = this%target_x + this%orbit_radius * cos(this%orbit_pitch) * sin(this%orbit_yaw)
    camera_y = this%target_y + this%orbit_radius * sin(this%orbit_pitch)
    camera_z = this%target_z + this%orbit_radius * cos(this%orbit_pitch) * cos(this%orbit_yaw)

    call this%program%use_program()
    call gl_uniform2f(this%resolution_uniform, real(width, c_float), real(height, c_float))
    call gl_uniform3f(this%camera_origin_uniform, real(camera_x, c_float), real(camera_y, c_float), real(camera_z, c_float))
    call gl_uniform3f(this%camera_target_uniform, real(this%target_x, c_float), &
      real(this%target_y, c_float), real(this%target_z, c_float))
    call gl_uniform3f(this%camera_up_uniform, 0.0_c_float, 1.0_c_float, 0.0_c_float)
    call gl_uniform1i(this%fractal_uniform, int(this%fractal_kind, c_int))
    call gl_uniform1i(this%max_steps_uniform, int(max_steps_for_preset(this%preset), c_int))
    call gl_uniform1i(this%variant_uniform, int(this%mandelbulb_variant, c_int))
    call this%quad%draw()

    if (runtime_is_offline()) return
    if (.not. this%show_hud) return
    call runtime_text_begin_frame()
    write (fractal_line, '(a,a)') "FRACTAL: ", trim(fractal_name(this%fractal_kind))
    write (variant_line, '(a,a)') "VARIANT: ", trim(mandelbulb_variant_name(this%fractal_kind, this%mandelbulb_variant))
    write (preset_line, '(a,a)') "PRESET: ", trim(preset_name(this%preset))
    write (radius_line, '(a,f5.2)') "RADIUS: ", this%orbit_radius
    if (this%auto_orbit) then
      orbit_line = "ORBIT: AUTO"
    else
      orbit_line = "ORBIT: MANUAL"
    end if
    call runtime_draw_text(fractal_line, 28, height - 172, 2, [0.96, 0.88, 0.58, 1.0])
    call runtime_draw_text(variant_line, 28, height - 140, 2, [0.88, 0.73, 0.92, 1.0])
    call runtime_draw_text(preset_line, 28, height - 108, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(radius_line, 28, height - 76, 2, [0.84, 0.88, 0.93, 1.0])
    call runtime_draw_text(orbit_line, 28, height - 44, 2, [0.62, 0.67, 0.75, 1.0])
    call runtime_draw_text(controls_text, &
      max(24, width - runtime_measure_text(controls_text, 2) - 24), &
      height - 44, 2, [0.62, 0.67, 0.75, 1.0])
  end subroutine mandelbulb_render

  subroutine reset_camera(this)
    class(mandelbulb_scene_type), intent(inout) :: this

    this%auto_orbit = .true.
    this%idle_seconds = 0.0_real64
    this%orbit_pitch = 0.18_real64
    this%orbit_radius = 4.6_real64
    this%orbit_yaw = 0.0_real64
    this%target_x = 0.0_real64
    this%target_y = 0.1_real64
    this%target_z = 0.0_real64
  end subroutine reset_camera

  integer function max_steps_for_preset(preset) result(value)
    integer, intent(in), value :: preset

    select case (preset)
    case (preset_draft)
      value = 64
    case (preset_heavy)
      value = 256
    case default
      value = 128
    end select
  end function max_steps_for_preset

  character(len=16) function preset_name(preset) result(name)
    integer, intent(in), value :: preset

    select case (preset)
    case (preset_draft)
      name = "draft"
    case (preset_heavy)
      name = "heavy"
    case default
      name = "normal"
    end select
  end function preset_name

  character(len=16) function fractal_name(kind) result(name)
    integer, intent(in), value :: kind

    if (kind == fractal_menger) then
      name = "Menger"
    else
      name = "Mandelbulb"
    end if
  end function fractal_name

  character(len=16) function mandelbulb_variant_name(fractal_kind, variant) result(name)
    integer, intent(in), value :: fractal_kind
    integer, intent(in), value :: variant

    if (fractal_kind /= fractal_mandelbulb) then
      name = "default"
      return
    end if

    select case (variant)
    case (mandelbulb_variant_classic)
      name = "classic"
    case (mandelbulb_variant_nebula)
      name = "nebula"
    case default
      name = "cathedral"
    end select
  end function mandelbulb_variant_name
end module scene_mandelbulb
