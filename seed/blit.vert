#version 460 core

layout(location = 0) in vec3 Position;
layout(location = 1) in vec4 Color;
layout(location = 2) in vec2 TextureCoordinate;

out vec4 v_color;
out vec2 v_uv;

void main() {
    v_color = Color;
    v_uv = TextureCoordinate;
    gl_Position = vec4(Position, 1.0);
}