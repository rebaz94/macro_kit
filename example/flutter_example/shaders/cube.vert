#version 460 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec4 color;

layout(location = 0) out vec4 v_color;

layout(binding = 0) uniform FrameInfo {
  mat4 mvp;
} frame_info;

void main() {
  v_color = color;
  gl_Position = frame_info.mvp * vec4(position, 1.0);
}
