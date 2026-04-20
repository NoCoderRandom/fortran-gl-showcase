module scene_array_landscape
  use, intrinsic :: iso_c_binding, only: c_float, c_int, c_loc
  use app_runtime, only: runtime_draw_text, runtime_framebuffer_size, runtime_is_offline, runtime_measure_text
  use app_runtime, only: runtime_request_menu, runtime_text_begin_frame, runtime_was_pressed
  use core_kinds, only: real64
  use core_text_file, only: read_text_file
  use gl_loader, only: gl_active_texture, gl_bind_texture, gl_clamp_to_edge, gl_delete_textures, gl_float, gl_gen_textures
  use gl_loader, only: gl_linear, gl_rgba, gl_rgba16f, gl_tex_image_2d, gl_tex_parameteri, gl_texture0, gl_texture_2d
  use gl_loader, only: gl_texture_mag_filter, gl_texture_min_filter, gl_texture_wrap_s, gl_texture_wrap_t
  use gl_loader, only: gl_uniform1f, gl_uniform1i, gl_uniform2f
  use platform_input, only: key_escape, key_h, key_r, key_space
  use render_fullscreen_quad, only: fullscreen_quad_cache
  use render_shader, only: shader_program
  use scene_base, only: post_settings_t, scene_type, tone_aces
  implicit none (type, external)
  private

  integer, parameter :: field_width = 320
  integer, parameter :: field_height = 320

  public :: array_landscape_scene_type
  public :: setup_array_landscape_scene

  type, extends(scene_type) :: array_landscape_scene_type
    type(fullscreen_quad_cache) :: quad
    type(shader_program) :: program
    integer(c_int) :: field_texture = 0_c_int
    integer(c_int) :: field_uniform = -1
    integer(c_int) :: resolution_uniform = -1
    integer(c_int) :: texel_uniform = -1
    integer(c_int) :: time_uniform = -1
    logical :: paused = .false.
    logical :: show_hud = .true.
    real(real64) :: scene_time = 0.0_real64
    real(c_float), pointer :: field_texture_data(:, :, :) => null()
    real(real64), allocatable :: x_grid(:, :)
    real(real64), allocatable :: y_grid(:, :)
    real(real64), allocatable :: field(:, :)
    real(real64), allocatable :: warp_x(:, :)
    real(real64), allocatable :: warp_y(:, :)
    real(real64), allocatable :: gradient(:, :)
  contains
    procedure :: destroy => array_landscape_destroy
    procedure :: get_name => array_landscape_get_name
    procedure :: get_post_settings => array_landscape_get_post_settings
    procedure :: init => array_landscape_init
    procedure :: render => array_landscape_render
    procedure :: update => array_landscape_update
  end type array_landscape_scene_type

contains
  subroutine setup_array_landscape_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(array_landscape_scene_type :: scene)
  end subroutine setup_array_landscape_scene

  subroutine array_landscape_init(this)
    class(array_landscape_scene_type), intent(inout) :: this
    character(len=:), allocatable :: fragment_source
    character(len=:), allocatable :: vertex_source

    call this%quad%initialize()
    vertex_source = read_text_file("assets/shaders/fractal2d.vert")
    fragment_source = read_text_file("assets/shaders/array_landscape.frag")
    call this%program%build(vertex_source, fragment_source, "array landscape")
    this%resolution_uniform = this%program%uniform("u_resolution")
    this%time_uniform = this%program%uniform("u_time")
    this%field_uniform = this%program%uniform("u_field")
    this%texel_uniform = this%program%uniform("u_texel")
    allocate(this%field_texture_data(4, field_width, field_height))
    allocate(this%x_grid(field_width, field_height))
    allocate(this%y_grid(field_width, field_height))
    allocate(this%field(field_width, field_height))
    allocate(this%warp_x(field_width, field_height))
    allocate(this%warp_y(field_width, field_height))
    allocate(this%gradient(field_width, field_height))
    call initialize_coordinate_grids(this)
    call allocate_field_texture(this)
    call rebuild_field(this)
  end subroutine array_landscape_init

  subroutine array_landscape_destroy(this)
    class(array_landscape_scene_type), intent(inout) :: this
    integer(c_int), target :: texture_id

    texture_id = this%field_texture
    if (texture_id /= 0_c_int) call gl_delete_textures(1_c_int, c_loc(texture_id))
    if (associated(this%field_texture_data)) deallocate(this%field_texture_data)
    if (allocated(this%x_grid)) deallocate(this%x_grid)
    if (allocated(this%y_grid)) deallocate(this%y_grid)
    if (allocated(this%field)) deallocate(this%field)
    if (allocated(this%warp_x)) deallocate(this%warp_x)
    if (allocated(this%warp_y)) deallocate(this%warp_y)
    if (allocated(this%gradient)) deallocate(this%gradient)
    call this%program%destroy()
    call this%quad%destroy()
  end subroutine array_landscape_destroy

  subroutine array_landscape_get_name(this, value)
    class(array_landscape_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "array_landscape"
  end subroutine array_landscape_get_name

  function array_landscape_get_post_settings(this) result(settings)
    class(array_landscape_scene_type), intent(in) :: this
    type(post_settings_t) :: settings

    if (.false.) print *, same_type_as(this, this)
    settings%bloom_strength = 0.9
    settings%bloom_threshold = 1.02
    settings%tone_map_mode = tone_aces
    settings%vignette_strength = 0.22
    settings%grain_strength = 0.014
  end function array_landscape_get_post_settings

  subroutine array_landscape_update(this, delta_seconds)
    class(array_landscape_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
    if (runtime_was_pressed(key_escape)) call runtime_request_menu()
    if (runtime_was_pressed(key_h)) this%show_hud = .not. this%show_hud
    if (runtime_was_pressed(key_space)) this%paused = .not. this%paused
    if (runtime_was_pressed(key_r)) this%scene_time = 0.0_real64
    if (.not. this%paused) this%scene_time = this%scene_time + delta_seconds
    call rebuild_field(this)
  end subroutine array_landscape_update

  subroutine array_landscape_render(this)
    class(array_landscape_scene_type), intent(inout) :: this
    integer :: height
    integer :: width

    call runtime_framebuffer_size(width, height)
    call gl_active_texture(gl_texture0)
    call gl_bind_texture(gl_texture_2d, this%field_texture)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, field_width, field_height, 0_c_int, &
      gl_rgba, gl_float, c_loc(this%field_texture_data))
    call this%program%use_program()
    call gl_uniform2f(this%resolution_uniform, real(width, c_float), real(height, c_float))
    call gl_uniform2f(this%texel_uniform, 1.0_c_float / real(field_width, c_float), 1.0_c_float / real(field_height, c_float))
    call gl_uniform1f(this%time_uniform, real(this%scene_time, c_float))
    call gl_uniform1i(this%field_uniform, 0_c_int)
    call this%quad%draw()

    if (runtime_is_offline()) return
    if (.not. this%show_hud) return
    call draw_hud(this, width, height)
  end subroutine array_landscape_render

  subroutine initialize_coordinate_grids(this)
    class(array_landscape_scene_type), intent(inout) :: this
    integer :: i
    integer :: j
    real(real64) :: x_line(field_width)
    real(real64) :: y_line(field_height)

    do i = 1, field_width
      x_line(i) = -1.0_real64 + 2.0_real64 * real(i - 1, real64) / real(field_width - 1, real64)
    end do
    do j = 1, field_height
      y_line(j) = -1.0_real64 + 2.0_real64 * real(j - 1, real64) / real(field_height - 1, real64)
    end do

    this%x_grid = spread(x_line, dim=2, ncopies=field_height)
    this%y_grid = spread(y_line, dim=1, ncopies=field_width)
  end subroutine initialize_coordinate_grids

  subroutine allocate_field_texture(this)
    class(array_landscape_scene_type), intent(inout) :: this
    integer(c_int), target :: texture_id

    texture_id = 0_c_int
    call gl_gen_textures(1_c_int, c_loc(texture_id))
    this%field_texture = texture_id
    call gl_bind_texture(gl_texture_2d, this%field_texture)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_min_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_mag_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
    call gl_tex_image_2d(gl_texture_2d, 0_c_int, gl_rgba16f, field_width, field_height, 0_c_int, &
      gl_rgba, gl_float, c_loc(this%field_texture_data))
    call gl_bind_texture(gl_texture_2d, 0_c_int)
  end subroutine allocate_field_texture

  subroutine rebuild_field(this)
    class(array_landscape_scene_type), intent(inout) :: this
    real(real64) :: t
    real(real64), allocatable :: ridge(:, :)
    real(real64), allocatable :: basin(:, :)
    real(real64), allocatable :: lattice(:, :)
    real(real64), allocatable :: radial(:, :)
    real(real64), allocatable :: dx(:, :)
    real(real64), allocatable :: dy(:, :)
    real(real64) :: grad_max
    real(real64) :: field_min
    real(real64) :: field_max

    t = this%scene_time
    allocate(ridge(field_width, field_height))
    allocate(basin(field_width, field_height))
    allocate(lattice(field_width, field_height))
    allocate(radial(field_width, field_height))
    allocate(dx(field_width, field_height))
    allocate(dy(field_width, field_height))

    this%warp_x = this%x_grid + 0.18_real64 * sin(2.7_real64 * this%y_grid + 0.6_real64 * t) + &
      0.12_real64 * cos(3.3_real64 * (this%x_grid + this%y_grid) - 0.4_real64 * t)
    this%warp_y = this%y_grid + 0.15_real64 * cos(2.2_real64 * this%x_grid - 0.5_real64 * t) - &
      0.10_real64 * sin(3.0_real64 * (this%x_grid - this%y_grid) + 0.8_real64 * t)

    radial = sqrt(this%warp_x**2 + this%warp_y**2)
    ridge = sin(10.0_real64 * this%warp_x + 1.1_real64 * t) + cos(8.0_real64 * this%warp_y - 0.9_real64 * t)
    basin = sin(6.0_real64 * radial - 1.4_real64 * t)
    lattice = sin(7.0_real64 * (this%warp_x + this%warp_y) + 0.7_real64 * t) * &
      cos(7.0_real64 * (this%warp_x - this%warp_y) - 0.5_real64 * t)

    this%field = exp(-0.85_real64 * radial**2) * (0.55_real64 * ridge + 0.60_real64 * basin + 0.35_real64 * lattice)
    this%field = this%field + 0.25_real64 * sin(12.0_real64 * radial - 0.8_real64 * ridge)
    this%field = tanh(1.15_real64 * this%field)

    dx = 0.5_real64 * (cshift(this%field, -1, dim=1) - cshift(this%field, 1, dim=1))
    dy = 0.5_real64 * (cshift(this%field, -1, dim=2) - cshift(this%field, 1, dim=2))
    this%gradient = sqrt(dx * dx + dy * dy)

    field_min = minval(this%field)
    field_max = maxval(this%field)
    if (field_max > field_min) then
      this%field_texture_data(1, :, :) = real((this%field - field_min) / (field_max - field_min), c_float)
    else
      this%field_texture_data(1, :, :) = 0.5_c_float
    end if

    grad_max = max(1.0e-6_real64, maxval(this%gradient))
    this%field_texture_data(2, :, :) = real(min(1.0_real64, this%gradient / grad_max), c_float)
    this%field_texture_data(3, :, :) = real(0.5_real64 + 0.5_real64 * sin(5.0_real64 * radial - 0.9_real64 * t), c_float)
    this%field_texture_data(4, :, :) = 1.0_c_float

    deallocate(ridge)
    deallocate(basin)
    deallocate(lattice)
    deallocate(radial)
    deallocate(dx)
    deallocate(dy)
  end subroutine rebuild_field

  subroutine draw_hud(this, width, height)
    class(array_landscape_scene_type), intent(in) :: this
    integer, intent(in), value :: width
    integer, intent(in), value :: height
    character(len=*), parameter :: controls = "SPACE PAUSE  R RESET  H HUD  ESC MENU"
    character(len=64) :: time_line

    call runtime_text_begin_frame()
    call runtime_draw_text("Array Landscape", 28, 30, 3, [0.95, 0.84, 0.49, 1.0])
    call runtime_draw_text("Fortran whole-array field synthesis turned into a lit signal terrain.", &
      28, 72, 2, [0.84, 0.88, 0.94, 1.0])
    write (time_line, '(a,f6.2,a)') "TIME: ", this%scene_time, " S"
    call runtime_draw_text(trim(time_line), 28, height - 82, 2, [0.84, 0.88, 0.94, 1.0])
    if (this%paused) call runtime_draw_text("PAUSED", 28, height - 50, 2, [0.95, 0.84, 0.49, 1.0])
    call runtime_draw_text(controls, max(24, width - runtime_measure_text(controls, 2) - 24), &
      height - 50, 2, [0.60, 0.65, 0.73, 1.0])
  end subroutine draw_hud
end module scene_array_landscape
