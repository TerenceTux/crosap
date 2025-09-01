#version 460
#extension GL_EXT_samplerless_texture_functions: enable

layout(origin_upper_left) in vec4 gl_FragCoord;

layout(binding = 0) uniform texture2D tex[8];

layout(location = 0) flat in vec4 obj_color;
layout(location = 1) flat in int tex_id;
layout(location = 2) flat in ivec2 tex_offset;
layout(location = 3) flat in ivec2 tex_pos;
layout(location = 4) flat in ivec2 tex_size;

layout(location = 0) out vec4 out_color;

void main() {
    ivec2 pixel = ivec2(floor(gl_FragCoord.xy));
    ivec2 texture_coord = pixel - tex_offset;
    out_color = texelFetch(tex[tex_id], tex_pos + (texture_coord % tex_size), 0) * obj_color;
}
