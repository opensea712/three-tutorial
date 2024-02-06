precision highp float;

attribute vec3 a_position;
attribute vec3 a_normal;

uniform mat4 u_projectionViewMatrix;
uniform mat4 u_modelMatrix;

varying vec3 v_normal;
varying vec3 v_baseNormal;
varying vec3 v_worldPosition;

void main () {
    v_normal = normalize((u_modelMatrix * vec4(a_normal, 0.0)).xyz);
    v_baseNormal = v_normal;
    v_worldPosition = (u_modelMatrix * vec4(a_position, 1.0)).xyz;

    gl_Position = u_projectionViewMatrix * vec4(v_worldPosition, 1.0);
}
