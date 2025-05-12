#version 450

layout(location = 0) in vec2 in_position;
layout(location = 1) in vec2 tex_coord_in;
layout(location = 2) in uint tex_idx_in;

layout(location = 0) out vec3 frag_colour;
layout(location = 1) out vec2 tex_coord_out;
layout(location = 2) out uint tex_idx_out;

void main() {
  gl_Position = vec4(in_position, 0.0, 1.0);
  frag_colour = vec3(in_position, 1.0);
  tex_coord_out = tex_coord_in;
  tex_idx_out = tex_idx_in;
}
