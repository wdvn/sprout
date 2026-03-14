#version 330
in vec2 position;
void main() {
    gl_Position = vec4(position, 0.0, 1.0);
}
---
#version 330
out vec4 frag_color;
void main() {
    frag_color = vec4(0.0, 0.0, 0.0, 1.0);
}
