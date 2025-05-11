#version 450

layout(location = 0) in vec3 frag_colour;
layout(location = 1) in vec2 tex_coord;

layout(location = 0) out vec4 out_colour;

layout(binding = 0) uniform sampler2D tex_sampler;

void main() {
  // out_colour = vec4(frag_colour, 1.0);
  out_colour = textureLod(tex_sampler, tex_coord, 0);
}
