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
  float falloff = exp(-3.6 * radius2);
  vec3 color = palette * v_color.rgb * mix(1.4, 5.2, falloff);
  fragColor = vec4(color, falloff * max(v_color.a, 0.08));
}
