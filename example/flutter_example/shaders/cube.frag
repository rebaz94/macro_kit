#version 460 core

// Saving this file recompiles and reloads the shader in debug builds.
//
// Each side of the cube keeps its own color from the mesh. Change
// COLOR_MULTIPLIER below and save — every face recolors live.
layout(location = 0) in vec4 v_color;
layout(location = 0) out vec4 frag_color;

const float COLOR_MULTIPLIER = 0.8;

void main() {
  frag_color = vec4(v_color.rgb * COLOR_MULTIPLIER, v_color.a);
}
