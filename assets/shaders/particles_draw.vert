#version 330 core

layout(location = 0) in vec4 a_position_age;
layout(location = 1) in vec4 a_color;

out vec4 v_color;
out float v_age;

uniform vec3 u_camera_origin;
uniform vec3 u_camera_target;
uniform vec3 u_camera_up;
uniform float u_lifetime;
uniform vec2 u_resolution;

void main() {
  vec3 forward = normalize(u_camera_target - u_camera_origin);
  vec3 right = normalize(cross(forward, u_camera_up));
  vec3 up = normalize(cross(right, forward));
  vec3 relative = a_position_age.xyz - u_camera_origin;
  vec3 view = vec3(dot(relative, right), dot(relative, up), dot(relative, forward));
  float inv_z = 1.0 / max(view.z, 0.05);
  vec2 clip = vec2(view.x * inv_z, view.y * inv_z);
  clip.x *= u_resolution.y / u_resolution.x;

  gl_Position = vec4(clip, 0.0, 1.0);
  gl_PointSize = clamp(14.0 * inv_z, 1.0, 16.0);
  v_color = a_color;
  v_age = clamp(a_position_age.w / u_lifetime, 0.0, 1.0);
}
