#version 330 core

// Mandelbulb distance-estimator baseline adapted from the public derivation by
// Daniel White / Paul Nylander. This stage adds tetrahedral normals and a
// single directional light and soft shadows while keeping the march simple.

in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform vec3 u_camera_origin;
uniform vec3 u_camera_target;
uniform vec3 u_camera_up;
uniform int u_fractal_type;
uniform int u_max_steps;

const float max_distance = 24.0;
const float hit_floor = 0.00008;

vec2 mandelbulb_de(vec3 position) {
  vec3 z = position;
  float dr = 1.0;
  float radius = 0.0;
  float trapped_iter = 0.0;

  for (int i = 0; i < 12; ++i) {
    radius = length(z);
    trapped_iter = float(i);
    if (radius > 4.0) break;

    float theta = acos(clamp(z.z / max(radius, 1e-6), -1.0, 1.0));
    float phi = atan(z.y, z.x);
    float zr = pow(radius, 7.0);
    dr = 8.0 * pow(radius, 7.0) * dr + 1.0;
    theta *= 8.0;
    phi *= 8.0;
    z = zr * vec3(
      sin(theta) * cos(phi),
      sin(theta) * sin(phi),
      cos(theta)
    ) + position;
  }

  return vec2(0.5 * log(max(radius, 1e-6)) * radius / dr, trapped_iter);
}

vec2 menger_de(vec3 position) {
  vec3 z = position;
  float scale = 1.0;

  for (int i = 0; i < 5; ++i) {
    z = abs(z);
    if (z.x < z.y) z.xy = z.yx;
    if (z.x < z.z) z.xz = z.zx;
    if (z.y < z.z) z.yz = z.zy;
    z = 3.0 * z - 2.0;
    if (z.z < -1.0) z.z += 2.0;
    scale *= 3.0;
  }

  float cube = max(max(abs(z.x), abs(z.y)), abs(z.z)) - 1.0;
  return vec2(cube / scale, 5.0);
}

vec2 scene_de(vec3 position) {
  if (u_fractal_type == 1) return menger_de(position);
  return mandelbulb_de(position);
}

vec3 mandelbulb_orbit_trap(vec3 position) {
  vec3 z = position;
  float trap_x = 1e6;
  float trap_y = 1e6;
  float trap_z = 1e6;
  float trap_origin = 1e6;

  for (int i = 0; i < 12; ++i) {
    float radius = length(z);
    trap_x = min(trap_x, abs(z.x));
    trap_y = min(trap_y, abs(z.y));
    trap_z = min(trap_z, abs(z.z));
    trap_origin = min(trap_origin, radius);
    if (radius > 4.0) break;

    float theta = acos(clamp(z.z / max(radius, 1e-6), -1.0, 1.0));
    float phi = atan(z.y, z.x);
    float zr = pow(radius, 8.0);
    theta *= 8.0;
    phi *= 8.0;
    z = zr * vec3(
      sin(theta) * cos(phi),
      sin(theta) * sin(phi),
      cos(theta)
    ) + position;
  }

  return vec3(
    exp(-6.0 * trap_x),
    exp(-6.0 * trap_y),
    exp(-3.0 * trap_origin)
  );
}

vec3 menger_orbit_trap(vec3 position) {
  vec3 z = position;
  float trap_axis = 1e6;
  float trap_corner = 1e6;
  float trap_center = 1e6;

  for (int i = 0; i < 5; ++i) {
    trap_axis = min(trap_axis, min(abs(z.x), min(abs(z.y), abs(z.z))));
    trap_corner = min(trap_corner, length(abs(z) - vec3(1.0)));
    trap_center = min(trap_center, length(z));
    z = abs(z);
    if (z.x < z.y) z.xy = z.yx;
    if (z.x < z.z) z.xz = z.zx;
    if (z.y < z.z) z.yz = z.zy;
    z = 3.0 * z - 2.0;
    if (z.z < -1.0) z.z += 2.0;
  }

  return vec3(
    exp(-4.0 * trap_axis),
    exp(-2.0 * trap_corner),
    exp(-2.0 * trap_center)
  );
}

vec3 scene_orbit_trap(vec3 position) {
  if (u_fractal_type == 1) return menger_orbit_trap(position);
  return mandelbulb_orbit_trap(position);
}

vec3 estimate_normal(vec3 position) {
  const float k = 0.57735027;
  vec2 e = vec2(1.0, -1.0) * 0.0009;
  return normalize(
    e.xyy * scene_de(position + e.xyy).x +
    e.yyx * scene_de(position + e.yyx).x +
    e.yxy * scene_de(position + e.yxy).x +
    e.xxx * scene_de(position + e.xxx).x
  );
}

float soft_shadow(vec3 origin, vec3 direction, float max_t) {
  float result = 1.0;
  float travel = 0.02;

  // Standard penumbra estimator in the IQ style, using k ~= 16.
  for (int step = 0; step < 48; ++step) {
    if (travel >= max_t) break;
    float distance_to_surface = scene_de(origin + direction * travel).x;
    if (distance_to_surface < 0.00005) return 0.0;
    result = min(result, 16.0 * distance_to_surface / travel);
    travel += clamp(distance_to_surface, 0.01, 0.25);
  }

  return clamp(result, 0.0, 1.0);
}

float ambient_occlusion(vec3 position, vec3 normal) {
  float occlusion = 0.0;
  float weight = 1.0;
  float distance_along_normal = 0.02;

  for (int step = 0; step < 5; ++step) {
    float sample_distance = scene_de(position + normal * distance_along_normal).x;
    occlusion += weight * max(0.0, distance_along_normal - sample_distance);
    distance_along_normal *= 1.9;
    weight *= 0.55;
  }

  return clamp(1.0 - 1.6 * occlusion, 0.0, 1.0);
}

void main() {
  vec2 pixel = (gl_FragCoord.xy - 0.5 * u_resolution) / u_resolution.y;
  vec3 forward = normalize(u_camera_target - u_camera_origin);
  vec3 right = normalize(cross(forward, u_camera_up));
  vec3 up = normalize(cross(right, forward));
  vec3 ray_dir = normalize(forward + pixel.x * right + pixel.y * up);

  float pixel_radius = 2.0 / max(u_resolution.x, u_resolution.y);
  float travel = 0.0;
  float hit_iteration = 0.0;
  vec3 hit_point = vec3(0.0);
  bool hit = false;

  for (int step = 0; step < 256; ++step) {
    if (step >= u_max_steps) break;
    vec3 sample_point = u_camera_origin + ray_dir * travel;
    vec2 de = scene_de(sample_point);
    float epsilon = max(hit_floor, pixel_radius * max(travel, 1.0));
    if (de.x < epsilon) {
      hit = true;
      hit_iteration = de.y;
      hit_point = sample_point;
      break;
    }
    travel += de.x;
    if (travel > max_distance) break;
  }

  if (!hit) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }

  float tone = hit_iteration / 12.0;
  vec3 bronze = mix(vec3(0.16, 0.10, 0.05), vec3(0.88, 0.70, 0.34), tone);
  if (u_fractal_type == 1) {
    bronze = mix(vec3(0.16, 0.14, 0.12), vec3(0.74, 0.68, 0.56), tone);
  }
  vec3 trap = scene_orbit_trap(hit_point);
  bronze = mix(bronze, vec3(0.26, 0.56, 0.72), 0.35 * trap.x);
  bronze = mix(bronze, vec3(0.78, 0.50, 0.24), 0.25 * trap.y);
  bronze += 0.18 * trap.z;
  vec3 normal = estimate_normal(hit_point);
  vec3 light_dir = normalize(vec3(0.45, 0.85, 0.28));
  float shadow = soft_shadow(hit_point + normal * 0.004, light_dir, 8.0);
  float ao = ambient_occlusion(hit_point, normal);
  float lambert = max(dot(normal, light_dir), 0.0);
  vec3 shaded = bronze * ao * (0.10 + 0.90 * lambert * shadow);
  float crease = pow(clamp(tone, 0.0, 1.0), 3.0) * shadow;
  vec3 emissive = vec3(1.8, 1.2, 0.5) * 0.65 * crease;
  vec3 fog_color = vec3(0.22, 0.17, 0.12);
  float fog_amount = 1.0 - exp(-0.09 * travel);
  vec3 color = mix(shaded + emissive, fog_color, clamp(fog_amount, 0.0, 1.0));
  fragColor = vec4(color, 1.0);
}
