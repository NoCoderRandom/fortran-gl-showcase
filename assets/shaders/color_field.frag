#version 330 core

in vec2 v_uv;
out vec4 frag_color;

uniform vec2 u_resolution;
uniform float u_time;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i + vec2(0.0, 0.0));
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
  vec2 uv = v_uv * 2.0 - 1.0;
  uv.x *= u_resolution.x / max(u_resolution.y, 1.0);

  float t = u_time * 0.18;
  float n1 = noise(uv * 1.7 + vec2(t, -t * 0.7));
  float n2 = noise(uv * 3.6 + vec2(-t * 1.4, t * 0.9));
  float n3 = noise(uv * 7.0 + vec2(t * 0.6, t * 1.1));
  float field = 0.55 * n1 + 0.30 * n2 + 0.15 * n3;
  float contour = smoothstep(0.48, 0.52, fract(field * 7.0 - t * 1.7));

  vec3 base = mix(vec3(0.08, 0.10, 0.15), vec3(0.18, 0.26, 0.34), field);
  vec3 warm = vec3(0.80, 0.42, 0.26);
  vec3 cool = vec3(0.28, 0.72, 0.96);
  vec3 color = base;
  color += mix(warm, cool, 0.5 + 0.5 * sin(t * 9.0 + field * 10.0)) * contour * 0.22;
  color += 0.15 * vec3(0.9, 0.8, 0.7) * exp(-3.5 * dot(uv, uv));

  frag_color = vec4(color, 1.0);
}
