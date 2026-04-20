#version 330 core

in vec2 v_uv;
out vec4 fragColor;

uniform sampler2D u_field;
uniform vec2 u_resolution;
uniform vec2 u_texel;
uniform float u_time;

vec3 palette(float t) {
  vec3 a = vec3(0.30, 0.26, 0.22);
  vec3 b = vec3(0.35, 0.30, 0.28);
  vec3 c = vec3(1.00, 0.90, 0.72);
  vec3 d = vec3(0.08, 0.18, 0.31);
  return a + b * cos(6.28318 * (c * t + d));
}

void main() {
  vec4 center = texture(u_field, v_uv);
  float h = center.r;
  float left = texture(u_field, v_uv - vec2(u_texel.x, 0.0)).r;
  float right = texture(u_field, v_uv + vec2(u_texel.x, 0.0)).r;
  float down = texture(u_field, v_uv - vec2(0.0, u_texel.y)).r;
  float up = texture(u_field, v_uv + vec2(0.0, u_texel.y)).r;
  float gx = right - left;
  float gy = up - down;
  vec3 normal = normalize(vec3(-gx * 3.4, 1.0, -gy * 3.4));
  vec3 light_dir = normalize(vec3(-0.38, 0.72, 0.56));
  float lambert = max(dot(normal, light_dir), 0.0);
  float rim = pow(clamp(1.0 - normal.y, 0.0, 1.0), 2.4);
  float energy = center.g;
  float pulse = center.b;
  float sweep = 0.5 + 0.5 * sin(6.28318 * (v_uv.x * 0.65 + v_uv.y * 0.4) - 0.35 * u_time);
  vec3 base = palette(0.10 + 0.55 * h + 0.25 * pulse + 0.10 * sweep);
  vec3 accent = mix(vec3(0.12, 0.52, 0.72), vec3(0.96, 0.54, 0.22), pulse);
  vec3 color = mix(base, accent, 0.35 * energy);
  color *= 0.28 + 0.92 * lambert;
  color += 0.18 * rim * vec3(0.78, 0.88, 1.00);
  color += 0.20 * energy * vec3(0.20, 0.62, 0.82);
  color += 0.12 * smoothstep(0.62, 0.95, h) * vec3(1.00, 0.88, 0.58);
  vec3 fog = mix(vec3(0.05, 0.07, 0.10), vec3(0.18, 0.16, 0.14), v_uv.y);
  color = mix(color, fog, 0.16 + 0.12 * (1.0 - lambert));
  fragColor = vec4(color, 1.0);
}
