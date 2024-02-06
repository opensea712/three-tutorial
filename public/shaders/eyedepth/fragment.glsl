precision highp float;

varying vec4 v_clipSpacePosition;

const float PackUpscale = 256.0 / 255.0;
const float UnpackDownscale = 255.0 / 256.0;

const vec3 PackFactors = vec3(256.0 * 256.0 * 256.0, 256.0 * 256.0,  256.0);
const vec4 UnpackFactors = UnpackDownscale / vec4(PackFactors, 1.0);

const float ShiftRight8 = 1.0 / 256.0;

vec4 packDepthToRGBA( const in float v ) {
    vec4 r = vec4( fract( v * PackFactors ), v );
    r.yzw -= r.xyz * ShiftRight8; // tidy overflow
    return r * PackUpscale;
}

void main () {
    float ndcDepth = v_clipSpacePosition.z / v_clipSpacePosition.w;
    gl_FragColor = packDepthToRGBA(ndcDepth * 0.5 + 0.5);
}
