#version 330 core

in vec2 v_uv;
out vec4 frag_color;

uniform vec2 u_resolution;
uniform float u_time;

float ring(vec2 p, float radius, float width) {
  float d = abs(length(p) - radius);
  return exp(-d * d / max(width * width, 1e-4));
}

void main() {
  vec2 uv = v_uv * 2.0 - 1.0;
  uv.x *= u_resolution.x / max(u_resolution.y, 1.0);

  float t = u_time;
  vec2 a = uv - vec2(sin(t * 0.8) * 0.35, cos(t * 0.7) * 0.18);
  vec2 b = uv - vec2(cos(t * 0.5) * -0.42, sin(t * 0.9) * 0.24);
  vec2 c = uv - vec2(sin(t * 0.37) * 0.10, cos(t * 0.42) * -0.28);

  float glow_a = ring(a, 0.28 + 0.05 * sin(t * 1.7), 0.035);
  float glow_b = ring(b, 0.18 + 0.04 * cos(t * 1.4), 0.028);
  float glow_c = ring(c, 0.11 + 0.03 * sin(t * 1.1 + 2.0), 0.020);

  float core_a = exp(-10.0 * dot(a, a));
  float core_b = exp(-14.0 * dot(b, b));
  float core_c = exp(-22.0 * dot(c, c));

  float spokes = pow(max(0.0, cos(atan(uv.y, uv.x) * 8.0 + t * 1.6)), 18.0);
  float flare = spokes * exp(-2.2 * length(uv));

  vec3 color = vec3(0.01, 0.02, 0.05);
  color += vec3(4.8, 1.2, 0.5) * glow_a;
  color += vec3(0.6, 3.8, 5.4) * glow_b;
  color += vec3(5.5, 5.0, 1.5) * glow_c;
  color += vec3(2.8, 1.3, 0.6) * core_a;
  color += vec3(0.6, 2.6, 4.2) * core_b;
  color += vec3(4.0, 3.4, 1.3) * core_c;
  color += vec3(2.6, 2.0, 3.8) * flare;

  float vignette = smoothstep(1.5, 0.2, length(uv));
  color *= mix(0.8, 1.0, vignette);

  frag_color = vec4(color, 1.0);
}
