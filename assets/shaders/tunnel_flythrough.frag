#version 330 core

in vec2 v_uv;
out vec4 frag_color;

uniform vec2 u_resolution;
uniform float u_time;

vec3 palette(float t) {
  vec3 a = vec3(0.24, 0.28, 0.38);
  vec3 b = vec3(0.56, 0.40, 0.24);
  vec3 c = vec3(0.80, 0.72, 0.48);
  vec3 d = vec3(0.18, 0.44, 0.78);
  return a + b * cos(6.28318 * (c * t + d));
}

void main() {
  vec2 uv = v_uv * 2.0 - 1.0;
  uv.x *= u_resolution.x / max(u_resolution.y, 1.0);

  float t = u_time * 1.6;
  float r = max(length(uv), 0.04);
  float angle = atan(uv.y, uv.x);
  float travel = 1.0 / r + t;
  float bands = 0.5 + 0.5 * sin(travel * 6.0 + angle * 4.0);
  float ribs = 0.5 + 0.5 * sin(travel * 11.0 - angle * 7.0);
  float center_glow = exp(-10.0 * r);
  float edge_falloff = smoothstep(1.25, 0.16, r);

  vec3 color = palette(0.05 * travel + 0.15 * bands);
  color *= 0.35 + 0.65 * bands;
  color += palette(0.09 * travel - 0.22) * ribs * 0.45;
  color += vec3(1.8, 1.4, 0.9) * center_glow;
  color *= edge_falloff;
  color += vec3(0.01, 0.02, 0.03);

  frag_color = vec4(color, 1.0);
}
