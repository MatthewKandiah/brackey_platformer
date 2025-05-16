#version 450

#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in vec3 frag_colour;
layout(location = 1) in vec2 tex_coord;
layout(location = 2) in flat uint tex_idx;

layout(location = 0) out vec4 out_colour;

layout(binding = 0) uniform sampler2D tex_sampler[3];

void main() {
  out_colour = textureLod(tex_sampler[nonuniformEXT(tex_idx)], tex_coord, 0);
}
