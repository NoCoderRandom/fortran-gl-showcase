#version 330 core

// Smooth iteration adapts the well-known continuous escape-time approach.
// Reference idea: https://iquilezles.org/articles/msetsmooth/

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform vec2 u_center_x;
uniform vec2 u_center_y;
uniform vec2 u_scale;
uniform vec2 u_julia_c;
uniform sampler2D u_palette;
uniform float u_palette_phase;
uniform float u_time;
uniform int u_fractal_type;
uniform int u_max_iter;
uniform int u_orbit_trap_mode;

vec2 quick_two_sum(float a, float b) {
  float s = a + b;
  float e = b - (s - a);
  return vec2(s, e);
}

vec2 two_sum(float a, float b) {
  float s = a + b;
  float bb = s - a;
  float e = (a - (s - bb)) + (b - bb);
  return vec2(s, e);
}

vec2 two_prod(float a, float b) {
  const float split = 4097.0;
  float p = a * b;
  float a_split = a * split;
  float b_split = b * split;
  float a_hi = a_split - (a_split - a);
  float b_hi = b_split - (b_split - b);
  float a_lo = a - a_hi;
  float b_lo = b - b_hi;
  float e = ((a_hi * b_hi - p) + a_hi * b_lo + a_lo * b_hi) + a_lo * b_lo;
  return vec2(p, e);
}

vec2 ds(float value) {
  return vec2(value, 0.0);
}

vec2 ds_add(vec2 a, vec2 b) {
  vec2 s = two_sum(a.x, b.x);
  float e = a.y + b.y + s.y;
  return quick_two_sum(s.x, e);
}

vec2 ds_sub(vec2 a, vec2 b) {
  vec2 s = two_sum(a.x, -b.x);
  float e = a.y - b.y + s.y;
  return quick_two_sum(s.x, e);
}

vec2 ds_mul(vec2 a, vec2 b) {
  vec2 p = two_prod(a.x, b.x);
  float e = a.x * b.y + a.y * b.x + p.y;
  return quick_two_sum(p.x, e);
}

float ds_to_float(vec2 a) {
  return a.x + a.y;
}

vec2 ds_abs(vec2 a) {
  return ds_to_float(a) < 0.0 ? vec2(-a.x, -a.y) : a;
}

vec3 palette_lookup(float t) {
  return texture(u_palette, vec2(fract(t), 0.5)).rgb;
}

void main() {
  vec2 frag = gl_FragCoord.xy - 0.5 * u_resolution;
  vec2 coord = frag / u_resolution.y;
  vec2 x = ds_add(u_center_x, ds_mul(u_scale, ds(coord.x)));
  vec2 y = ds_add(u_center_y, ds_mul(u_scale, ds(coord.y)));

  vec2 cx = x;
  vec2 cy = y;
  vec2 zx = ds(0.0);
  vec2 zy = ds(0.0);
  if (u_fractal_type == 1) {
    zx = x;
    zy = y;
    cx = ds(u_julia_c.x);
    cy = ds(u_julia_c.y);
  }

  float trap = 1.0e6;
  float radius2 = 0.0;
  int iter = 0;
  for (int step = 0; step < 2048; ++step) {
    if (step >= u_max_iter) break;
    float zxf = ds_to_float(zx);
    float zyf = ds_to_float(zy);
    radius2 = zxf * zxf + zyf * zyf;
    if (radius2 > 256.0) {
      iter = step;
      break;
    }

    if (u_orbit_trap_mode == 1) {
      trap = min(trap, abs(length(vec2(zxf, zyf)) - 0.45));
    } else if (u_orbit_trap_mode == 2) {
      trap = min(trap, abs(zyf - zxf * 0.35));
    }

    vec2 x_term = ds_sub(ds_mul(zx, zx), ds_mul(zy, zy));
    vec2 y_term = ds_mul(ds(2.0), ds_mul(zx, zy));
    if (u_fractal_type == 2) {
      zx = ds_abs(zx);
      zy = ds_abs(zy);
      x_term = ds_sub(ds_mul(zx, zx), ds_mul(zy, zy));
      y_term = ds_mul(ds(2.0), ds_mul(zx, zy));
    }

    zx = ds_add(x_term, cx);
    zy = ds_add(y_term, cy);
    iter = step + 1;
  }

  bool escaped = radius2 > 256.0;
  vec3 color;
  if (escaped) {
    float radius = max(sqrt(radius2), 1.0001);
    float mu = float(iter) + 1.0 - log(log(radius)) / log(2.0);
    float trap_mix = 0.0;
    if (u_orbit_trap_mode != 0) {
      trap_mix = 1.0 - exp(-18.0 * trap);
    }
    vec3 base = palette_lookup(mu * 0.024 + u_palette_phase);
    vec3 accent = palette_lookup(mu * 0.024 + u_palette_phase + 0.125);
    vec3 detail = palette_lookup(mu * 0.017 + 0.06 * sin(0.7 * u_time) + u_palette_phase + 0.31);
    float bright = 0.82 + 1.55 * smoothstep(0.0, 1.0, fract(mu * 0.08));
    color = mix(mix(base, accent, trap_mix), detail, 0.22) * bright;
  } else {
    float x_f = ds_to_float(x);
    float y_f = ds_to_float(y);
    float swirl = 0.5 + 0.5 * sin(0.11 * u_time + x_f * 15.0 + y_f * 11.0);
    float veins = 0.5 + 0.5 * cos(0.07 * u_time - x_f * 21.0 + y_f * 16.0);
    vec3 inner_base = vec3(0.08, 0.05, 0.12);
    vec3 inner_warm = vec3(0.34, 0.16, 0.08);
    vec3 inner_cool = vec3(0.16, 0.34, 0.42);
    vec3 interior = mix(inner_base, inner_warm, swirl);
    interior = mix(interior, inner_cool, 0.38 * veins);
    interior += 0.12 * palette_lookup(0.09 * u_time + 0.08 * swirl + 0.03 * veins + u_palette_phase);
    color = interior;
  }

  fragColor = vec4(color, 1.0);
}
