module render_post_process
  use, intrinsic :: iso_c_binding, only: c_float, c_int, c_loc, c_null_ptr
  use gl_loader, only: gl_active_texture, gl_bind_framebuffer, gl_bind_texture, gl_check_framebuffer_status
  use gl_loader, only: gl_clamp_to_edge, gl_clear, gl_clear_color, gl_color_attachment0, gl_color_buffer_bit
  use gl_loader, only: gl_delete_framebuffers, gl_delete_textures, gl_float, gl_framebuffer, gl_framebuffer_complete
  use gl_loader, only: gl_framebuffer_texture_2d, gl_gen_framebuffers, gl_gen_textures, gl_linear, gl_rgba
  use gl_loader, only: gl_rgba16f, gl_tex_image_2d, gl_tex_parameteri, gl_texture0, gl_texture1
  use gl_loader, only: gl_texture_2d, gl_texture_mag_filter, gl_texture_min_filter, gl_texture_wrap_s
  use gl_loader, only: gl_texture_wrap_t, gl_uniform1f, gl_uniform1i, gl_uniform2f, gl_viewport
  use render_fullscreen_quad, only: fullscreen_quad_cache
  use render_shader, only: shader_program
  use scene_base, only: post_settings_t
  implicit none (type, external)
  private

  integer, parameter :: bloom_levels = 4
  integer, parameter :: upsample_levels = bloom_levels - 1

  public :: post_process

  type :: post_process
    type(fullscreen_quad_cache) :: quad
    type(shader_program) :: bright_program
    type(shader_program) :: down_program
    type(shader_program) :: up_program
    type(shader_program) :: composite_program
    integer(c_int) :: scene_fbo = 0
    integer(c_int) :: scene_tex = 0
    integer(c_int) :: bloom_fbo(bloom_levels) = 0
    integer(c_int) :: bloom_tex(bloom_levels) = 0
    integer(c_int) :: up_fbo(upsample_levels) = 0
    integer(c_int) :: up_tex(upsample_levels) = 0
    integer :: width = 0
    integer :: height = 0
  contains
    procedure :: begin_scene_target => post_begin_scene_target
    procedure :: destroy => post_destroy
    procedure :: end_and_present => post_end_and_present
    procedure :: ensure_size => post_ensure_size
    procedure :: initialize => post_initialize
  end type post_process

  character(len=*), parameter :: post_vertex_shader = &
    "#version 330 core"//new_line("a")// &
    "const vec2 positions[3] = vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));"//new_line("a")// &
    "out vec2 uv;"//new_line("a")// &
    "void main(){ vec2 p=positions[gl_VertexID]; uv=p*0.5+0.5; gl_Position=vec4(p,0.0,1.0); }"

  character(len=*), parameter :: bright_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec2 uv; out vec4 fragColor; uniform sampler2D u_scene; uniform float u_threshold;"//new_line("a")// &
    "void main(){ vec3 c=texture(u_scene,uv).rgb; float l=max(max(c.r,c.g),c.b);"//new_line("a")// &
    "float knee=max(0.0001,u_threshold*0.5); float s=max(l-u_threshold+knee,0.0)/(2.0*knee);"//new_line("a")// &
    "float w=max(l-u_threshold,0.0)+knee*s*s; fragColor=vec4(c*(w/max(l,0.0001)),1.0); }"

  character(len=*), parameter :: down_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec2 uv; out vec4 fragColor; uniform sampler2D u_source; uniform vec2 u_texel;"//new_line("a")// &
    "void main(){ vec3 c=texture(u_source,uv).rgb*0.25;"//new_line("a")// &
    "c+=texture(u_source,uv+vec2(u_texel.x,0)).rgb*0.1875; c+=texture(u_source,uv-vec2(u_texel.x,0)).rgb*0.1875;"//new_line("a")// &
    "c+=texture(u_source,uv+vec2(0,u_texel.y)).rgb*0.1875; c+=texture(u_source,uv-vec2(0,u_texel.y)).rgb*0.1875;"//new_line("a")// &
    "fragColor=vec4(c,1.0); }"

  character(len=*), parameter :: up_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec2 uv; out vec4 fragColor; uniform sampler2D u_low; uniform sampler2D u_high; uniform vec2 u_texel;"//new_line("a")// &
    "void main(){ vec3 low=texture(u_low,uv).rgb; vec3 blur=texture(u_high,uv).rgb*0.4;"//new_line("a")// &
    "blur+=texture(u_high,uv+vec2(u_texel.x,0)).rgb*0.15; blur+=texture(u_high,uv-vec2(u_texel.x,0)).rgb*0.15;"//new_line("a")// &
    "blur+=texture(u_high,uv+vec2(0,u_texel.y)).rgb*0.15; blur+=texture(u_high,uv-vec2(0,u_texel.y)).rgb*0.15;"//new_line("a")// &
    "fragColor=vec4(low+blur,1.0); }"

  character(len=*), parameter :: composite_fragment_shader = &
    "#version 330 core"//new_line("a")// &
    "in vec2 uv; out vec4 fragColor;"//new_line("a")// &
    "uniform sampler2D u_scene; uniform sampler2D u_bloom;"//new_line("a")// &
    "uniform float u_bloom_strength;"//new_line("a")// &
    "uniform int u_tone; uniform float u_vignette; uniform float u_grain;"//new_line("a")// &
    "uniform int u_chromatic; uniform float u_time; uniform vec2 u_texel;"//new_line("a")// &
    "vec3 aces(vec3 x){"//new_line("a")// &
    "  float a=2.51,b=0.03,c=2.43,d=0.59,e=0.14;"//new_line("a")// &
    "  return clamp((x*(a*x+b))/(x*(c*x+d)+e),0.0,1.0);"//new_line("a")// &
    "}"//new_line("a")// &
    "float hash(vec2 p){"//new_line("a")// &
    "  return fract(sin(dot(p,vec2(127.1,311.7))+u_time*17.0)*43758.5453);"//new_line("a")// &
    "}"//new_line("a")// &
    "void main(){"//new_line("a")// &
    "  vec3 scene=texture(u_scene,uv).rgb;"//new_line("a")// &
    "  if(u_chromatic==1){"//new_line("a")// &
    "    scene.r=texture(u_scene,uv+u_texel).r;"//new_line("a")// &
    "    scene.b=texture(u_scene,uv-u_texel).b;"//new_line("a")// &
    "  }"//new_line("a")// &
    "  vec3 color=scene+texture(u_bloom,uv).rgb*u_bloom_strength;"//new_line("a")// &
    "  if(u_tone==2){"//new_line("a")// &
    "    color=color/(1.0+color);"//new_line("a")// &
    "  } else {"//new_line("a")// &
    "    color=aces(color);"//new_line("a")// &
    "  }"//new_line("a")// &
    "  float vig=1.0-u_vignette*smoothstep(0.15,0.95,distance(uv,vec2(0.5)));"//new_line("a")// &
    "  color*=vig;"//new_line("a")// &
    "  color += (hash(gl_FragCoord.xy)-0.5)*u_grain;"//new_line("a")// &
    "  color=pow(max(color,0.0),vec3(1.0/2.2));"//new_line("a")// &
    "  fragColor=vec4(color,1.0);"//new_line("a")// &
    "}"

contains
  subroutine post_initialize(this)
    class(post_process), intent(inout) :: this

    call this%quad%initialize()
    call this%bright_program%build(post_vertex_shader, bright_fragment_shader, "post bright")
    call this%down_program%build(post_vertex_shader, down_fragment_shader, "post down")
    call this%up_program%build(post_vertex_shader, up_fragment_shader, "post up")
    call this%composite_program%build(post_vertex_shader, composite_fragment_shader, "post composite")
  end subroutine post_initialize

  subroutine post_ensure_size(this, width, height)
    class(post_process), intent(inout) :: this
    integer, intent(in), value :: width
    integer, intent(in), value :: height
    integer :: level
    integer :: level_width
    integer :: level_height

    if (this%scene_tex == 0) call this%initialize()
    if (this%width == width .and. this%height == height) return
    call destroy_targets(this)
    this%width = width
    this%height = height

    call allocate_target(this%scene_fbo, this%scene_tex, width, height)
    do level = 1, bloom_levels
      level_width = max(1, width / (2 ** level))
      level_height = max(1, height / (2 ** level))
      call allocate_target(this%bloom_fbo(level), this%bloom_tex(level), level_width, level_height)
    end do
    do level = 1, upsample_levels
      level_width = max(1, width / (2 ** level))
      level_height = max(1, height / (2 ** level))
      call allocate_target(this%up_fbo(level), this%up_tex(level), level_width, level_height)
    end do
  end subroutine post_ensure_size

  subroutine post_begin_scene_target(this, width, height)
    class(post_process), intent(inout) :: this
    integer, intent(in), value :: width
    integer, intent(in), value :: height

    call this%ensure_size(width, height)
    call gl_bind_framebuffer(gl_framebuffer, this%scene_fbo)
    call gl_viewport(0_c_int, 0_c_int, int(width, c_int), int(height, c_int))
    call gl_clear_color(0.0_c_float, 0.0_c_float, 0.0_c_float, 1.0_c_float)
    call gl_clear(gl_color_buffer_bit)
  end subroutine post_begin_scene_target

  subroutine post_end_and_present(this, settings, time_seconds)
    class(post_process), intent(inout) :: this
    type(post_settings_t), intent(in) :: settings
    real, intent(in), value :: time_seconds
    integer :: level
    integer :: level_w
    integer :: level_h

    call gl_bind_framebuffer(gl_framebuffer, this%bloom_fbo(1))
    call gl_viewport(0_c_int, 0_c_int, int(max(1, this%width / 2), c_int), int(max(1, this%height / 2), c_int))
    call this%bright_program%use_program()
    call bind_texture_unit(this%scene_tex, gl_texture0, 0, this%bright_program%uniform("u_scene"))
    call gl_uniform1f(this%bright_program%uniform("u_threshold"), settings%bloom_threshold)
    call this%quad%draw()

    do level = 2, bloom_levels
      level_w = max(1, this%width / (2 ** level))
      level_h = max(1, this%height / (2 ** level))
      call gl_bind_framebuffer(gl_framebuffer, this%bloom_fbo(level))
      call gl_viewport(0_c_int, 0_c_int, int(level_w, c_int), int(level_h, c_int))
      call this%down_program%use_program()
      call bind_texture_unit(this%bloom_tex(level - 1), gl_texture0, 0, this%down_program%uniform("u_source"))
      call gl_uniform2f( &
        this%down_program%uniform("u_texel"), &
        1.0_c_float / real(max(1, this%width / (2 ** (level - 1))), c_float), &
        1.0_c_float / real(max(1, this%height / (2 ** (level - 1))), c_float) &
      )
      call this%quad%draw()
    end do

    level = upsample_levels
    level_w = max(1, this%width / (2 ** level))
    level_h = max(1, this%height / (2 ** level))
    call gl_bind_framebuffer(gl_framebuffer, this%up_fbo(level))
    call gl_viewport(0_c_int, 0_c_int, int(level_w, c_int), int(level_h, c_int))
    call this%up_program%use_program()
    call bind_texture_unit(this%bloom_tex(level), gl_texture0, 0, this%up_program%uniform("u_low"))
    call bind_texture_unit(this%bloom_tex(level + 1), gl_texture1, 1, this%up_program%uniform("u_high"))
    call gl_uniform2f( &
      this%up_program%uniform("u_texel"), &
      1.0_c_float / real(level_w, c_float), &
      1.0_c_float / real(level_h, c_float) &
    )
    call this%quad%draw()

    do level = upsample_levels - 1, 1, -1
      level_w = max(1, this%width / (2 ** level))
      level_h = max(1, this%height / (2 ** level))
      call gl_bind_framebuffer(gl_framebuffer, this%up_fbo(level))
      call gl_viewport(0_c_int, 0_c_int, int(level_w, c_int), int(level_h, c_int))
      call this%up_program%use_program()
      call bind_texture_unit(this%bloom_tex(level), gl_texture0, 0, this%up_program%uniform("u_low"))
      call bind_texture_unit(this%up_tex(level + 1), gl_texture1, 1, this%up_program%uniform("u_high"))
      call gl_uniform2f( &
        this%up_program%uniform("u_texel"), &
        1.0_c_float / real(level_w, c_float), &
        1.0_c_float / real(level_h, c_float) &
      )
      call this%quad%draw()
    end do

    call gl_bind_framebuffer(gl_framebuffer, 0_c_int)
    call gl_viewport(0_c_int, 0_c_int, int(this%width, c_int), int(this%height, c_int))
    call this%composite_program%use_program()
    call bind_texture_unit(this%scene_tex, gl_texture0, 0, this%composite_program%uniform("u_scene"))
    call bind_texture_unit(this%up_tex(1), gl_texture1, 1, this%composite_program%uniform("u_bloom"))
    call gl_uniform1f(this%composite_program%uniform("u_bloom_strength"), settings%bloom_strength)
    call gl_uniform1i(this%composite_program%uniform("u_tone"), settings%tone_map_mode)
    call gl_uniform1f(this%composite_program%uniform("u_vignette"), settings%vignette_strength)
    call gl_uniform1f(this%composite_program%uniform("u_grain"), settings%grain_strength)
    call gl_uniform1i(this%composite_program%uniform("u_chromatic"), merge(1, 0, settings%chromatic_ab))
    call gl_uniform1f(this%composite_program%uniform("u_time"), real(time_seconds, c_float))
    call gl_uniform2f( &
      this%composite_program%uniform("u_texel"), &
      1.0_c_float / real(max(1, this%width), c_float), &
      1.0_c_float / real(max(1, this%height), c_float) &
    )
    call this%quad%draw()
  end subroutine post_end_and_present

  subroutine post_destroy(this)
    class(post_process), intent(inout) :: this

    call destroy_targets(this)
    call this%bright_program%destroy()
    call this%down_program%destroy()
    call this%up_program%destroy()
    call this%composite_program%destroy()
    call this%quad%destroy()
  end subroutine post_destroy

  subroutine destroy_targets(this)
    class(post_process), intent(inout) :: this
    integer(c_int), target :: ids(bloom_levels)
    integer(c_int), target :: scene_id
    integer(c_int), target :: up_ids(upsample_levels)
    integer :: level

    scene_id = this%scene_tex
    if (scene_id /= 0) call gl_delete_textures(1_c_int, c_loc(scene_id))
    scene_id = this%scene_fbo
    if (scene_id /= 0) call gl_delete_framebuffers(1_c_int, c_loc(scene_id))
    ids = this%bloom_tex
    do level = 1, bloom_levels
      if (ids(level) /= 0) call gl_delete_textures(1_c_int, c_loc(ids(level)))
    end do
    ids = this%bloom_fbo
    do level = 1, bloom_levels
      if (ids(level) /= 0) call gl_delete_framebuffers(1_c_int, c_loc(ids(level)))
    end do
    up_ids = this%up_tex
    do level = 1, upsample_levels
      if (up_ids(level) /= 0) call gl_delete_textures(1_c_int, c_loc(up_ids(level)))
    end do
    up_ids = this%up_fbo
    do level = 1, upsample_levels
      if (up_ids(level) /= 0) call gl_delete_framebuffers(1_c_int, c_loc(up_ids(level)))
    end do
    this%scene_fbo = 0
    this%scene_tex = 0
    this%bloom_fbo = 0
    this%bloom_tex = 0
    this%up_fbo = 0
    this%up_tex = 0
  end subroutine destroy_targets

  subroutine allocate_target(fbo, texture, width, height)
    integer(c_int), intent(inout) :: fbo
    integer(c_int), intent(inout) :: texture
    integer, intent(in), value :: width
    integer, intent(in), value :: height
    integer(c_int), target :: fbo_id
    integer(c_int), target :: tex_id

    fbo_id = 0
    tex_id = 0
    call gl_gen_framebuffers(1_c_int, c_loc(fbo_id))
    call gl_gen_textures(1_c_int, c_loc(tex_id))
    fbo = fbo_id
    texture = tex_id
    call gl_bind_texture(gl_texture_2d, texture)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_min_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_mag_filter, gl_linear)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
    call gl_tex_parameteri(gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
    call gl_tex_image_2d( &
      gl_texture_2d, 0_c_int, gl_rgba16f, int(width, c_int), int(height, c_int), &
      0_c_int, gl_rgba, gl_float, c_null_ptr &
    )
    call gl_bind_framebuffer(gl_framebuffer, fbo)
    call gl_framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, texture, 0_c_int)
    if (gl_check_framebuffer_status(gl_framebuffer) /= gl_framebuffer_complete) error stop "Framebuffer incomplete."
    call gl_bind_framebuffer(gl_framebuffer, 0_c_int)
  end subroutine allocate_target

  subroutine bind_texture_unit(texture, unit_constant, unit_index, uniform_location)
    integer(c_int), intent(in), value :: texture
    integer(c_int), intent(in), value :: unit_constant
    integer(c_int), intent(in), value :: unit_index
    integer(c_int), intent(in), value :: uniform_location

    call gl_active_texture(unit_constant)
    call gl_bind_texture(gl_texture_2d, texture)
    call gl_uniform1i(uniform_location, unit_index)
  end subroutine bind_texture_unit
end module render_post_process
