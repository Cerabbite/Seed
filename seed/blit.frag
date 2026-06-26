#version 460 core

uniform sampler2D u_texture;

in vec4 v_color;
in vec2 v_uv;
out vec4 frag_color;

void main() {
    // Atlas is GL_R8 — red channel only, use as alpha
    float alpha = texture(u_texture, v_uv).r;
    frag_color = vec4(v_color.rgb, v_color.a * alpha);
}