cmake_minimum_required(VERSION 3.20)

project(
  FortranGLShowcase
  VERSION 0.1.0
  LANGUAGES C Fortran
)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

find_package(OpenGL REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GLFW REQUIRED glfw3)

add_executable(fortran_gl_showcase
  src/main.f90
  src/anim/keyframe_track.f90
  src/anim/timeline.f90
  src/anim/camera_spline.f90
  src/anim/tiny_parser.f90
  src/core/kinds.f90
  src/core/logger.f90
  src/core/logger_impl.f90
  src/core/frame_export.f90
  src/core/text_file.f90
  src/core/timing.f90
  src/platform/input.f90
  src/platform/window.f90
  src/gl/gl_loader.f90
  src/gl/gl_debug.f90
  src/render/font_data.f90
  src/render/palette_data.f90
  src/render/shader.f90
  src/render/fullscreen_quad.f90
  src/render/post_process.f90
  src/render/menu_background.f90
  src/render/text_renderer.f90
  src/app/app_runtime.f90
  src/scene/scene_base.f90
  src/scene/coming_soon_scene.f90
  src/scene/scene_anim_test.f90
  src/scene/scene_combined.f90
  src/scene/empty_scene.f90
  src/scene/scene_fractal2d.f90
  src/scene/scene_mandelbulb.f90
  src/scene/scene_particles.f90
  src/scene/scene_shader_art.f90
  src/scene/menu_scene.f90
  src/scene/scene_registry.f90
  src/app/app.f90
)

target_include_directories(fortran_gl_showcase PRIVATE ${GLFW_INCLUDE_DIRS})
target_link_libraries(fortran_gl_showcase PRIVATE ${GLFW_LIBRARIES} OpenGL::GL)
set_target_properties(fortran_gl_showcase PROPERTIES
  Fortran_STANDARD 2018
  Fortran_STANDARD_REQUIRED ON
)

if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  target_compile_options(fortran_gl_showcase PRIVATE
    -Wall
    -Wextra
    -Wimplicit-interface
    -fcheck=all
  )
endif()

target_compile_definitions(fortran_gl_showcase PRIVATE
  $<$<CONFIG:Debug>:FGS_DEBUG_BUILD=1>
)
