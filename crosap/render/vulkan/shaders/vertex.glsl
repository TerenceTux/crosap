#version 460

layout (constant_id = 0) const int window_width = 0;
layout (constant_id = 1) const int window_height = 0;

layout(location = 0) in ivec2 in_position;
layout(location = 1) in ivec2 in_size;
layout(location = 2) in vec4 in_color;
layout(location = 3) in ivec2 in_tex_pos;
layout(location = 4) in ivec2 in_tex_size;
layout(location = 5) in ivec2 in_tex_offset;
layout(location = 6) in int in_tex_id;

layout(location = 0) flat out vec4 obj_color;
layout(location = 1) flat out int tex_id;
layout(location = 2) flat out ivec2 tex_offset;
layout(location = 3) flat out ivec2 tex_pos;
layout(location = 4) flat out ivec2 tex_size;

void main() {
    ivec2 pos = ivec2(
        in_position.x + in_size.x * (gl_VertexIndex % 2),
        in_position.y + in_size.y * (gl_VertexIndex / 2)
    );
    vec2 relative = vec2(pos) / vec2(window_width, window_height);
    gl_Position = vec4(relative * 2 - vec2(1, 1), 0.0, 1.0);
    
    obj_color = in_color;
    tex_id = in_tex_id;
    tex_offset = in_position + in_tex_offset;
    tex_pos = in_tex_pos;
    tex_size = in_tex_size;
}
