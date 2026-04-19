module scene_base
  use core_kinds, only: real64
  implicit none (type, external)
  private

  public :: scene_type

  type, abstract :: scene_type
  contains
    procedure(scene_name), deferred :: get_name
    procedure(scene_init), deferred :: init
    procedure(scene_render), deferred :: render
    procedure(scene_update), deferred :: update
  end type scene_type

  abstract interface
    subroutine scene_name(this, value)
      import :: scene_type
      class(scene_type), intent(in) :: this
      character(len=*), intent(out) :: value
    end subroutine scene_name

    subroutine scene_init(this)
      import :: scene_type
      class(scene_type), intent(inout) :: this
    end subroutine scene_init

    subroutine scene_render(this)
      import :: scene_type
      class(scene_type), intent(inout) :: this
    end subroutine scene_render

    subroutine scene_update(this, delta_seconds)
      import :: real64, scene_type
      class(scene_type), intent(inout) :: this
      real(real64), intent(in), value :: delta_seconds
    end subroutine scene_update
  end interface
end module scene_base

