#version 330 core

in vec4 v_color;
in float v_age;
out vec4 fragColor;

uniform sampler2D u_palette;

void main() {
  vec2 p = gl_PointCoord * 2.0 - 1.0;
  float radius2 = dot(p, p);
  if (radius2 > 1.0) discard;

  vec3 palette = texture(u_palette, vec2(v_age, 0.5)).rgb;
  float falloff = exp(-4.8 * radius2);
  float core = exp(-18.0 * radius2);
  vec3 color = palette * v_color.rgb * (0.18 + 0.95 * falloff + 0.55 * core);
  fragColor = vec4(color, (0.42 * falloff + 0.16 * core) * max(v_color.a, 0.08));
}
