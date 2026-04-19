module scene_anim_test
  use, intrinsic :: iso_c_binding, only: c_float
  use app_runtime, only: runtime_draw_text, runtime_elapsed, runtime_framebuffer_size, runtime_request_menu
  use app_runtime, only: runtime_text_begin_frame, runtime_was_pressed
  use core_kinds, only: real64
  use core_logger, only: log_info
  use anim_camera_spline, only: camera_spline
  use anim_timeline, only: timeline_type
  use anim_tiny_parser, only: load_timeline_file
  use platform_input, only: key_escape
  use scene_base, only: scene_type
  implicit none (type, external)
  private

  public :: anim_test_scene_type
  public :: setup_anim_test_scene

  type, extends(scene_type) :: anim_test_scene_type
    type(timeline_type) :: timeline
    type(camera_spline) :: camera
    integer :: logged_second = -1
    real(real64) :: camera_position(3) = 0.0_real64
    real(real64) :: look_at(3) = 0.0_real64
  contains
    procedure :: destroy => anim_test_destroy
    procedure :: get_name => anim_test_get_name
    procedure :: init => anim_test_init
    procedure :: render => anim_test_render
    procedure :: update => anim_test_update
  end type anim_test_scene_type

contains
  subroutine setup_anim_test_scene(scene)
    class(scene_type), allocatable, intent(out) :: scene

    allocate(anim_test_scene_type :: scene)
  end subroutine setup_anim_test_scene

  subroutine anim_test_init(this)
    class(anim_test_scene_type), intent(inout) :: this

    call load_timeline_file("assets/timelines/demo.tl", this%timeline)
    call this%camera%configure("camera_pos", "camera_look")
    this%logged_second = -1
  end subroutine anim_test_init

  subroutine anim_test_destroy(this)
    class(anim_test_scene_type), intent(inout) :: this

    if (.false.) print *, same_type_as(this, this)
  end subroutine anim_test_destroy

  subroutine anim_test_get_name(this, value)
    class(anim_test_scene_type), intent(in) :: this
    character(len=*), intent(out) :: value

    if (.false.) print *, same_type_as(this, this)
    value = "anim_test"
  end subroutine anim_test_get_name

  subroutine anim_test_update(this, delta_seconds)
    class(anim_test_scene_type), intent(inout) :: this
    real(real64), intent(in), value :: delta_seconds
    integer :: second_marker

    if (delta_seconds < 0.0_real64) error stop "Negative frame delta detected."
    if (runtime_was_pressed(key_escape)) call runtime_request_menu()

    call this%camera%evaluate( &
      this%timeline, modulo(runtime_elapsed(), this%timeline%get_duration()), &
      this%camera_position, this%look_at &
    )
    second_marker = int(runtime_elapsed())
    if (second_marker /= this%logged_second) then
      call log_tracks(this, modulo(runtime_elapsed(), this%timeline%get_duration()))
      this%logged_second = second_marker
    end if
  end subroutine anim_test_update

  subroutine anim_test_render(this)
    class(anim_test_scene_type), intent(inout) :: this
    character(len=64) :: line_x
    character(len=64) :: line_y
    character(len=64) :: line_z
    character(len=64) :: look_line
    integer :: height
    integer :: width
    real(c_float) :: accent(4)
    real(c_float) :: body(4)

    call runtime_framebuffer_size(width, height)
    accent = [0.94_c_float, 0.78_c_float, 0.42_c_float, 1.0_c_float]
    body = [0.82_c_float, 0.87_c_float, 0.92_c_float, 1.0_c_float]

    call runtime_text_begin_frame()
    call runtime_draw_text("ANIM TEST", 36, 44, 4, accent)
    write (line_x, '(a,f7.3)') "CAM X: ", this%camera_position(1)
    write (line_y, '(a,f7.3)') "CAM Y: ", this%camera_position(2)
    write (line_z, '(a,f7.3)') "CAM Z: ", this%camera_position(3)
    write (look_line, '(a,3(f6.2,1x))') "LOOK: ", this%look_at(1), this%look_at(2), this%look_at(3)
    call runtime_draw_text(line_x, 40, 132, 2, body)
    call runtime_draw_text(line_y, 40, 164, 2, body)
    call runtime_draw_text(line_z, 40, 196, 2, body)
    call runtime_draw_text(look_line, 40, 228, 2, body)
    call runtime_draw_text("DEV SCENE FOR PROMPT 7A  -  CHECK LOG OUTPUT EACH SECOND  -  ESC MENU", &
      40, height - 48, 2, [0.60_c_float, 0.66_c_float, 0.74_c_float, 1.0_c_float])
  end subroutine anim_test_render

  subroutine log_tracks(this, time_value)
    class(anim_test_scene_type), intent(in) :: this
    real(real64), intent(in), value :: time_value
    character(len=64) :: label
    character(len=256) :: line
    integer :: index

    write (label, '(a,f6.2)') "anim_test t=", time_value
    call log_info(trim(label))
    do index = 1, this%timeline%get_track_count()
      call this%timeline%get_track_name(index, label)
      write (line, '(2a,f10.4)') "  ", trim(label)//"=", this%timeline%get_value(trim(label), time_value, 0.0_real64)
      call log_info(trim(line))
    end do
  end subroutine log_tracks
end module scene_anim_test
