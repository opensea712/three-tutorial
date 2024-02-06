precision highp float;

attribute vec3 a_position;

uniform mat4 u_projectionViewModelMatrix;

varying vec4 v_clipSpacePosition;

void main () {
    v_clipSpacePosition = u_projectionViewModelMatrix * vec4(a_position, 1.0);
    gl_Position = v_clipSpacePosition;
}
