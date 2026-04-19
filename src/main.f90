program main
  use core_kinds, only: real64
  use showcase_app, only: render_request, run_app, run_render
  implicit none (type, external)
  character(len=256) :: output_dir
  character(len=64) :: initial_scene
  character(len=64) :: option_name
  character(len=64) :: render_scene
  integer :: arg_count
  integer :: index
  integer :: render_fps
  integer :: render_height
  integer :: render_width
  logical :: do_render
  real(real64) :: render_seconds
  type(render_request) :: request

  initial_scene = ""
  output_dir = ""
  render_scene = ""
  render_fps = 0
  render_height = 720
  render_width = 1280
  render_seconds = 0.0_real64
  do_render = .false.
  arg_count = command_argument_count()
  index = 1
  do while (index <= arg_count)
    call get_command_argument(index, option_name)
    if (trim(option_name) == "--scene") then
      if (index >= arg_count) error stop "--scene requires a scene name."
      call get_command_argument(index + 1, initial_scene)
      index = index + 2
    else if (trim(option_name) == "--render") then
      if (index >= arg_count) error stop "--render requires a scene name."
      do_render = .true.
      call get_command_argument(index + 1, render_scene)
      index = index + 2
    else if (trim(option_name) == "--seconds") then
      if (index >= arg_count) error stop "--seconds requires a value."
      call get_command_argument(index + 1, option_name)
      read (option_name, *) render_seconds
      index = index + 2
    else if (trim(option_name) == "--fps") then
      if (index >= arg_count) error stop "--fps requires a value."
      call get_command_argument(index + 1, option_name)
      read (option_name, *) render_fps
      index = index + 2
    else if (trim(option_name) == "--width") then
      if (index >= arg_count) error stop "--width requires a value."
      call get_command_argument(index + 1, option_name)
      read (option_name, *) render_width
      index = index + 2
    else if (trim(option_name) == "--height") then
      if (index >= arg_count) error stop "--height requires a value."
      call get_command_argument(index + 1, option_name)
      read (option_name, *) render_height
      index = index + 2
    else if (trim(option_name) == "--out") then
      if (index >= arg_count) error stop "--out requires a directory."
      call get_command_argument(index + 1, output_dir)
      index = index + 2
    else
      index = index + 1
    end if
  end do

  if (do_render) then
    request%scene_name = trim(render_scene)
    request%seconds = render_seconds
    request%fps = render_fps
    request%width = render_width
    request%height = render_height
    request%output_dir = trim(output_dir)
    call run_render(request)
  else
    call run_app(trim(initial_scene))
  end if
end program main
