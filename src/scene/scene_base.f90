module scene_base
  use core_kinds, only: real64
  implicit none (type, external)
  private

  integer, parameter, public :: tone_aces = 1
  integer, parameter, public :: tone_reinhard = 2

  type, public :: post_settings_t
    real :: bloom_strength = 0.9
    real :: bloom_threshold = 1.0
    integer :: tone_map_mode = tone_aces
    real :: vignette_strength = 0.3
    real :: grain_strength = 0.02
    logical :: chromatic_ab = .false.
  end type post_settings_t

  public :: scene_type

  type, abstract :: scene_type
  contains
    procedure(scene_destroy), deferred :: destroy
    procedure :: get_post_settings => scene_get_post_settings_default
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

    subroutine scene_destroy(this)
      import :: scene_type
      class(scene_type), intent(inout) :: this
    end subroutine scene_destroy

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

contains
  function scene_get_post_settings_default(this) result(settings)
    class(scene_type), intent(in) :: this
    type(post_settings_t) :: settings

    if (.false.) print *, same_type_as(this, this)
    settings = post_settings_t()
  end function scene_get_post_settings_default
end module scene_base
