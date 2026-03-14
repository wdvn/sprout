#version 330
in vec2 position;
uniform vec2 center;
uniform vec4 color;
out vec4 frag_color;
void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    frag_color = color;
}
---
#version 330
in vec4 color;
out vec4 frag_color;
void main() {
    frag_color = color;
}
