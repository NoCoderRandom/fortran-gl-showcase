#version 330 core

in vec2 v_uv;
out vec4 frag_color;

uniform vec2 u_resolution;
uniform float u_time;

float wave_height(vec2 p, float t) {
  float h = 0.0;
  h += 0.55 * sin(p.x * 2.2 + t * 1.2);
  h += 0.30 * sin(p.y * 4.5 - t * 1.8);
  h += 0.18 * sin((p.x + p.y) * 7.0 + t * 0.8);
  h += 0.10 * cos(length(p * vec2(1.4, 0.9)) * 10.0 - t * 1.3);
  return h;
}

void main() {
  vec2 uv = v_uv * 2.0 - 1.0;
  uv.x *= u_resolution.x / max(u_resolution.y, 1.0);

  float t = u_time * 0.75;
  vec2 p = vec2(uv.x * 2.4, uv.y * 3.2 + 0.3 * sin(uv.x * 2.0 + t));
  float h = wave_height(p, t);
  float hx = wave_height(p + vec2(0.02, 0.0), t) - h;
  float hy = wave_height(p + vec2(0.0, 0.02), t) - h;
  vec3 normal = normalize(vec3(-hx * 10.0, 1.0, -hy * 10.0));

  vec3 light_dir = normalize(vec3(-0.45, 0.88, 0.12));
  vec3 view_dir = normalize(vec3(0.0, 0.8, 0.6));
  float diffuse = max(dot(normal, light_dir), 0.0);
  float specular = pow(max(dot(reflect(-light_dir, normal), view_dir), 0.0), 28.0);
  float fresnel = pow(1.0 - max(normal.y, 0.0), 3.0);
  float ridge = smoothstep(0.10, 0.55, h + diffuse * 0.45);
  float trough = smoothstep(-0.70, -0.05, -h);
  float foam = smoothstep(0.22, 0.60, ridge + fresnel * 0.5);

  vec3 deep = vec3(0.02, 0.10, 0.18);
  vec3 mid = vec3(0.07, 0.24, 0.36);
  vec3 crest = vec3(0.72, 1.04, 1.25);
  vec3 color = mix(deep, mid, clamp(0.45 + 0.55 * h, 0.0, 1.0));
  color *= 1.0 - 0.25 * trough;
  color += ridge * vec3(0.12, 0.18, 0.24);
  color += foam * crest * (0.28 + 0.75 * fresnel);
  color += specular * vec3(1.1, 0.95, 0.75);

  float horizon = smoothstep(-0.95, 0.8, uv.y);
  color = mix(color, color + vec3(0.10, 0.08, 0.04), horizon * 0.12);
  color += 0.05 * vec3(0.3, 0.6, 1.0) * exp(-10.0 * abs(uv.y + 0.05));

  frag_color = vec4(color, 1.0);
}
