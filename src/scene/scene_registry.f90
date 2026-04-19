module scene_registry
  use empty_scene, only: empty_scene_type
  use scene_base, only: scene_type
  implicit none (type, external)
  private

  integer, parameter :: max_scenes = 16

  public :: scene_descriptor
  public :: scene_registry_type

  type :: scene_descriptor
    character(len=:), allocatable :: name
    character(len=:), allocatable :: summary
  end type scene_descriptor

  type :: scene_registry_type
    integer :: count = 0
    type(scene_descriptor) :: entries(max_scenes)
  contains
    procedure :: create => scene_registry_create
    procedure :: default_scene_name => scene_registry_default_scene_name
    procedure :: register_defaults => scene_registry_register_defaults
  end type scene_registry_type
contains
  subroutine scene_registry_register_defaults(this)
    class(scene_registry_type), intent(inout) :: this

    this%count = 1
    this%entries(1)%name = "empty_scene"
    this%entries(1)%summary = "Dark-gray clear pass used for bootstrapping."
  end subroutine scene_registry_register_defaults

  subroutine scene_registry_default_scene_name(this, value)
    class(scene_registry_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (this%count <= 0) error stop "Scene registry is empty."
    value = this%entries(1)%name
  end subroutine scene_registry_default_scene_name

  subroutine scene_registry_create(this, name, scene)
    class(scene_registry_type), intent(in) :: this
    character(len=*), intent(in) :: name
    class(scene_type), allocatable, intent(out) :: scene

    if (this%count <= 0) error stop "Scene registry is empty."

    select case (trim(name))
    case ("empty_scene")
      allocate(empty_scene_type :: scene)
    case default
      error stop "Unknown scene requested."
    end select
  end subroutine scene_registry_create
end module scene_registry

