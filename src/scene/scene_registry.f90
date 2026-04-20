module scene_registry
  use scene_array_landscape, only: setup_array_landscape_scene
  use scene_anim_test, only: setup_anim_test_scene
  use scene_combined, only: setup_combined_scene
  use scene_fractal2d, only: setup_fractal2d_scene
  use scene_mandelbulb, only: setup_mandelbulb_scene
  use scene_particles, only: setup_particle_scene
  use scene_shader_art, only: setup_color_field_scene, setup_hdr_bloom_scene
  use scene_shader_art, only: setup_procedural_waves_scene, setup_tunnel_flythrough_scene
  use scene_base, only: scene_type
  implicit none (type, external)
  private

  integer, parameter :: max_scenes = 16

  public :: scene_descriptor
  public :: scene_registry_type
  public :: scene_registry_has_scene

  abstract interface
    subroutine scene_factory(scene)
      import :: scene_type
      class(scene_type), allocatable, intent(out) :: scene
    end subroutine scene_factory
  end interface

  type :: scene_descriptor
    character(len=:), allocatable :: name
    character(len=:), allocatable :: display_name
    character(len=:), allocatable :: short_description
    logical :: offline_capable = .false.
    procedure(scene_factory), pointer, nopass :: factory => null()
  end type scene_descriptor

  type :: scene_registry_type
    integer :: count = 0
    type(scene_descriptor) :: entries(max_scenes)
  contains
    procedure :: count_entries => scene_registry_count_entries
    procedure :: create => scene_registry_create
    procedure :: describe => scene_registry_describe
    procedure :: has_scene => scene_registry_has_scene
    procedure :: is_offline_capable => scene_registry_is_offline_capable
    procedure :: register_defaults => scene_registry_register_defaults
  end type scene_registry_type
contains
  subroutine scene_registry_register_defaults(this)
    class(scene_registry_type), intent(inout) :: this

    this%count = 9
    call set_entry_metadata(this%entries(1), "fractal_explorer", "Fractal Explorer", "Mandelbrot / Julia / Burning Ship", .true.)
    this%entries(1)%factory => make_fractal_explorer
    call set_entry_metadata(this%entries(2), "mandelbulb_cathedral", "Mandelbulb Cathedral", &
      "3D raymarched fractal, cinematic light", .true.)
    this%entries(2)%factory => make_mandelbulb_cathedral
    call set_entry_metadata(this%entries(3), "particle_galaxy", "Particle Galaxy", "GPU-simulated particle field", .true.)
    this%entries(3)%factory => make_particle_galaxy
    call set_entry_metadata(this%entries(4), "procedural_waves", "Procedural Waves", "shader-art surface", .true.)
    this%entries(4)%factory => make_procedural_waves
    call set_entry_metadata(this%entries(5), "hdr_bloom_demo", "HDR Bloom Demo", "bright emissive shapes with bloom", .true.)
    this%entries(5)%factory => make_hdr_bloom_demo
    call set_entry_metadata(this%entries(6), "tunnel_flythrough", "Tunnel Flythrough", &
      "procedural tube with palette animation", .true.)
    this%entries(6)%factory => make_tunnel_flythrough
    call set_entry_metadata(this%entries(7), "color_field", "Color Field", "pure shader art, ambient screensaver", .true.)
    this%entries(7)%factory => make_color_field
    call set_entry_metadata(this%entries(8), "combined_showcase", "Combined Showcase", "flagship animated piece", .true.)
    this%entries(8)%factory => make_combined_showcase
    call set_entry_metadata(this%entries(9), "array_landscape", "Array Landscape", &
      "Fortran array math driving a lit signal field", .true.)
    this%entries(9)%factory => make_array_landscape
  end subroutine scene_registry_register_defaults

  subroutine scene_registry_create(this, name, scene)
    class(scene_registry_type), intent(in) :: this
    character(len=*), intent(in) :: name
    class(scene_type), allocatable, intent(out) :: scene
    integer :: index

    if (trim(name) == "anim_test") then
      call make_anim_test(scene)
      return
    end if

    do index = 1, this%count
      if (trim(this%entries(index)%name) == trim(name)) then
        call this%entries(index)%factory(scene)
        return
      end if
    end do

    error stop "Unknown scene requested."
  end subroutine scene_registry_create

  subroutine scene_registry_describe(this, index, name, display_name, short_description)
    class(scene_registry_type), intent(in) :: this
    integer, intent(in), value :: index
    character(len=*), intent(out) :: name
    character(len=*), intent(out) :: display_name
    character(len=*), intent(out) :: short_description

    if (index < 1 .or. index > this%count) error stop "Scene registry index out of range."
    name = this%entries(index)%name
    display_name = this%entries(index)%display_name
    short_description = this%entries(index)%short_description
  end subroutine scene_registry_describe

  integer function scene_registry_count_entries(this) result(count)
    class(scene_registry_type), intent(in) :: this

    count = this%count
  end function scene_registry_count_entries

  logical function scene_registry_has_scene(this, name) result(found)
    class(scene_registry_type), intent(in) :: this
    character(len=*), intent(in) :: name
    integer :: index

    found = .false.
    do index = 1, this%count
      if (trim(this%entries(index)%name) == trim(name)) then
        found = .true.
        return
      end if
    end do
    if (trim(name) == "anim_test") found = .true.
  end function scene_registry_has_scene

  logical function scene_registry_is_offline_capable(this, name) result(capable)
    class(scene_registry_type), intent(in) :: this
    character(len=*), intent(in) :: name
    integer :: index

    capable = .false.
    do index = 1, this%count
      if (trim(this%entries(index)%name) == trim(name)) then
        capable = this%entries(index)%offline_capable
        return
      end if
    end do
  end function scene_registry_is_offline_capable

  subroutine set_entry_metadata(entry, name, display_name, short_description, offline_capable)
    type(scene_descriptor), intent(inout) :: entry
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: display_name
    character(len=*), intent(in) :: short_description
    logical, intent(in), value :: offline_capable

    entry%name = name
    entry%display_name = display_name
    entry%short_description = short_description
    entry%offline_capable = offline_capable
  end subroutine set_entry_metadata

  subroutine make_fractal_explorer(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_fractal2d_scene(scene)
  end subroutine make_fractal_explorer

  subroutine make_mandelbulb_cathedral(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_mandelbulb_scene(scene)
  end subroutine make_mandelbulb_cathedral

  subroutine make_particle_galaxy(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_particle_scene(scene)
  end subroutine make_particle_galaxy

  subroutine make_procedural_waves(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_procedural_waves_scene(scene)
  end subroutine make_procedural_waves

  subroutine make_hdr_bloom_demo(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_hdr_bloom_scene(scene)
  end subroutine make_hdr_bloom_demo

  subroutine make_tunnel_flythrough(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_tunnel_flythrough_scene(scene)
  end subroutine make_tunnel_flythrough

  subroutine make_color_field(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_color_field_scene(scene)
  end subroutine make_color_field

  subroutine make_combined_showcase(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_combined_scene(scene)
  end subroutine make_combined_showcase

  subroutine make_array_landscape(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_array_landscape_scene(scene)
  end subroutine make_array_landscape

  subroutine make_anim_test(scene)
    class(scene_type), allocatable, intent(out) :: scene

    call setup_anim_test_scene(scene)
  end subroutine make_anim_test
end module scene_registry
