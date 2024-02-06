//requires lightingcommon.glsl

varying vec3 v_baseNormal;

uniform float u_pupilNoiseOffset;
uniform vec3 u_eyePosition;

uniform vec3 u_lookDirection;

//
// Description : Array and textureless GLSL 2D simplex noise function.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : stegu
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//               https://github.com/stegu/webgl-noise
// 

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
  return mod289(((x*34.0)+1.0)*x);
}

float snoise(vec2 v)
  {
  const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                      0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                     -0.577350269189626,  // -1.0 + 2.0 * C.x
                      0.024390243902439); // 1.0 / 41.0
// First corner
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);

// Other corners
  vec2 i1;
  //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
  //i1.y = 1.0 - i1.x;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  // x0 = x0 - 0.0 + 0.0 * C.xx ;
  // x1 = x0 - i1 + 1.0 * C.xx ;
  // x2 = x0 - 1.0 + 2.0 * C.xx ;
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;

// Permutations
  i = mod289(i); // Avoid truncation effects in permutation
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
\t\t+ i.x + vec3(0.0, i1.x, 1.0 ));

  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;

// Gradients: 41 points uniformly over a line, mapped onto a diamond.
// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;

// Normalise gradients implicitly by scaling m
// Approximation of: m *= inversesqrt( a0*a0 + h*h );
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

// Compute final noise value at P
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

vec3 closestPointOnAxis (vec3 base, vec3 direction, vec3 point) {
    return base + dot(point - base, direction) * direction;
}

float distanceFromAxis (vec3 base, vec3 direction, vec3 point) {
    return distance(point, closestPointOnAxis(base, direction, point));
}

vec3 eyeColor (vec3 point) {
    //closest point on cylinder axis
    vec3 closestPoint = closestPointOnAxis(u_eyePosition, u_lookDirection, point);

    if (dot(u_lookDirection, v_worldPosition - u_eyePosition) < 0.0) return vec3(1.0);

    vec3 offset = point - closestPoint;

    //find plane of cylinder
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), u_lookDirection));
    vec3 up = cross(u_lookDirection, right);

    //project onto cylinder plane
    float x = dot(offset, right);
    float y = dot(offset, up);

    float PUPIL_FREQUENCY = 8.0;

    float theta = mod(atan(y, x) + PI + u_pupilNoiseOffset, 2.0 * PI);
    float r = 0.025 + snoise(vec2(PUPIL_FREQUENCY * theta / (2.0 * PI), 0.0)) * 0.003;

    return length(vec2(x, y)) < r ? vec3(0.0) : vec3(1.0);
}

/*
vec3 eyeColor (vec3 point) {
    return distanceFromAxis(u_eyePosition, u_lookDirection, point) < 0.03 ? vec3(0.0) : vec3(1.0);
}
*/

void main () {
    vec3 normal = normalize(v_normal);

    vec3 albedo = eyeColor(v_worldPosition);

    float roughness = 0.05;
    float F0 = 0.35;

    vec3 color = shadeSurfaceWithLights(v_worldPosition, normal, albedo, roughness, F0);

    gl_FragColor = vec4(gammaCorrect(color), 1.0);
}
