precision highp float;
precision highp sampler2D;

uniform vec3 u_cameraPosition;

uniform vec3 u_lightPosition0;
uniform mat4 u_lightProjectionViewMatrix0;
uniform sampler2D u_shadowDepthTexture0;
uniform vec2 u_shadowResolution0;
uniform vec3 u_lightColor0;
uniform float u_lightNear0;
uniform float u_lightFar0;

uniform vec3 u_lightPosition1;
uniform mat4 u_lightProjectionViewMatrix1;
uniform sampler2D u_shadowDepthTexture1;
uniform vec2 u_shadowResolution1;
uniform vec3 u_lightColor1;
uniform float u_lightNear1;
uniform float u_lightFar1;

uniform vec3 u_skinAlbedo;

varying vec3 v_normal;
varying vec3 v_worldPosition;

const float PI = 3.14159265;

float square (float x) {
    return x * x;
}

float fresnel (float F0, float lDotH) {
    float f = pow(1.0 - lDotH, 5.0);

    return (1.0 - F0) * f + F0;
}

float GGX (float alpha, float nDotH) {
    float a2 = square(alpha);

    return a2 / (PI * square(square(nDotH) * (a2 - 1.0) + 1.0));
}

float GGGX (float alpha, float nDotL, float nDotV) {
    float a2 = square(alpha);

    float gl = nDotL + sqrt(a2 + (1.0 - a2) * square(nDotL));
    float gv = nDotV + sqrt(a2 + (1.0 - a2) * square(nDotV));

    return 1.0 / (gl * gv);
}

float saturate (float x) {
    return clamp(x, 0.0, 1.0);
}

float specularBRDF (vec3 lightDirection, vec3 eyeDirection, vec3 normal, float roughness, float F0) {
    vec3 halfVector = normalize(lightDirection + eyeDirection);

    float nDotH = saturate(dot(normal, halfVector));
    float nDotL = saturate(dot(normal, lightDirection));
    float nDotV = saturate(dot(normal, eyeDirection));
    float lDotH = saturate(dot(lightDirection, halfVector));

    float D = GGX(roughness, nDotH);
    float G = GGGX(roughness, nDotL, nDotV);
    float F = fresnel(F0, lDotH);

    return D * G * F;
}

const float PackUpscale = 256. / 255.; // fraction -> 0..1 (including 1)
const float UnpackDownscale = 255. / 256.; // 0..1 -> fraction (excluding 1)

const vec3 PackFactors = vec3( 256. * 256. * 256., 256. * 256.,  256. );
const vec4 UnpackFactors = UnpackDownscale / vec4( PackFactors, 1. );

const float ShiftRight8 = 1. / 256.;

float unpackRGBAToDepth( const in vec4 v ) {
    return dot( v, UnpackFactors );
}

float texture2DCompare( sampler2D depths, vec2 uv, float compare ) {
    return step(compare, unpackRGBAToDepth(texture2D( depths, uv )));
}

float texture2DShadow( sampler2D depths, vec2 size, vec2 uv, float compare ) {
    return texture2DCompare(depths, uv, compare);
}

float texture2DShadowLerp( sampler2D depths, vec2 size, vec2 uv, float compare ) {
    const vec2 offset = vec2(0.0, 1.0);

    vec2 texelSize = vec2(1.0) / size;
    vec2 centroidUV = floor(uv * size + 0.5) / size;

    float lb = texture2DCompare(depths, centroidUV + texelSize * offset.xx, compare );
    float lt = texture2DCompare(depths, centroidUV + texelSize * offset.xy, compare );
    float rb = texture2DCompare(depths, centroidUV + texelSize * offset.yx, compare );
    float rt = texture2DCompare(depths, centroidUV + texelSize * offset.yy, compare );

    vec2 f = fract(uv * size + 0.5);

    float a = mix(lb, lt, f.y);
    float b = mix(rb, rt, f.y);
    float c = mix(a, b, f.x);

    return c;
}

float getShadow (vec3 worldPosition, mat4 projectionViewMatrix, sampler2D depthTexture, vec2 resolution) {
    vec4 lightSpacePosition = projectionViewMatrix * vec4(worldPosition, 1.0);
    lightSpacePosition /= lightSpacePosition.w;
    lightSpacePosition = lightSpacePosition * 0.5 + 0.5;
    vec2 lightSpaceCoordinates = lightSpacePosition.xy;

    <shadow>
}

float linearizeDepth (float depth, float near, float far) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near)); 
}

vec3 getTransmittedColor (vec3 worldPosition, vec3 normal, vec3 lightDirection, vec3 lightColor, mat4 lightProjectionViewMatrix, sampler2D depthTexture, float lightNear, float lightFar) {
    vec3 shrunkPosition = worldPosition - normal * 0.01;
    vec4 lightSpacePosition2 = lightProjectionViewMatrix * vec4(shrunkPosition, 1.0);
    lightSpacePosition2 /= lightSpacePosition2.w;
    lightSpacePosition2 = lightSpacePosition2 * 0.5 + 0.5;
    vec2 lightSpaceCoordinates2 = lightSpacePosition2.xy;

    float lightSample = unpackRGBAToDepth(texture2D(depthTexture, lightSpaceCoordinates2));
    float d = abs(linearizeDepth(lightSample, lightNear, lightFar) - linearizeDepth(lightSpacePosition2.z, lightNear, lightFar)) * 20.0;

    float dd = -d * d;
    vec3 profile = vec3(0.233, 0.455, 0.649) * exp(dd / 0.0064) +
                     vec3(0.1,   0.336, 0.344) * exp(dd / 0.0484) +
                     vec3(0.118, 0.198, 0.0)   * exp(dd / 0.187)  +
                     vec3(0.113, 0.007, 0.007) * exp(dd / 0.567)  +
                     vec3(0.358, 0.004, 0.0)   * exp(dd / 1.99)   +
                     vec3(0.078, 0.0,   0.0)   * exp(dd / 7.41);

    return profile * 1.0 * saturate(0.6 + dot(lightDirection, -normal)) * lightColor;
}

vec3 shadeSurfaceWithLightWithoutShadow (vec3 worldPosition, vec3 normal, vec3 albedo, float roughness, float F0, vec3 lightPosition, vec3 lightColor, mat4 projectionViewMatrix, sampler2D depthTexture, vec2 depthResolution) {
    vec3 eyeDirection = normalize(u_cameraPosition - worldPosition);
    vec3 lightDirection = normalize(lightPosition - worldPosition);

    float diffuse = saturate(dot(lightDirection, normal));
    float specular = specularBRDF(lightDirection, eyeDirection, normal, roughness, F0);

    vec3 color = (diffuse * 1.0 * albedo + specular * 1.0) * lightColor;

    return color;
}

vec3 shadeSurfaceWithLight (vec3 worldPosition, vec3 normal, vec3 albedo, float roughness, float F0, vec3 lightPosition, vec3 lightColor, mat4 projectionViewMatrix, sampler2D depthTexture, vec2 depthResolution) {
    float shadow = getShadow(worldPosition, projectionViewMatrix, depthTexture, depthResolution);

    vec3 color = shadeSurfaceWithLightWithoutShadow(worldPosition, normal, albedo, roughness, F0, lightPosition, lightColor, projectionViewMatrix, depthTexture, depthResolution) * shadow;

    return color;
}

vec3 shadeSurfaceWithLights (vec3 worldPosition, vec3 normal, vec3 albedo, float roughness, float F0) {
    vec3 total = shadeSurfaceWithLight(worldPosition, normal, albedo, roughness, F0, u_lightPosition0, u_lightColor0, u_lightProjectionViewMatrix0, u_shadowDepthTexture0, u_shadowResolution0);
    total += shadeSurfaceWithLight(worldPosition, normal, albedo, roughness, F0, u_lightPosition1, u_lightColor1, u_lightProjectionViewMatrix1, u_shadowDepthTexture1, u_shadowResolution1);

    return total;
}

vec3 shadeSurfaceWithLightsWithTransmittance (vec3 worldPosition, vec3 normal, vec3 albedo, float roughness, float F0) {
    vec3 total = shadeSurfaceWithLights(worldPosition, normal, albedo, roughness, F0);    

    total += getTransmittedColor(worldPosition, normal, normalize(u_lightPosition0 - worldPosition), u_lightColor0, u_lightProjectionViewMatrix0, u_shadowDepthTexture0, u_lightNear0, u_lightFar0); 
    total += getTransmittedColor(worldPosition, normal, normalize(u_lightPosition1 - worldPosition), u_lightColor1, u_lightProjectionViewMatrix1, u_shadowDepthTexture1, u_lightNear1, u_lightFar1);

    return total;
}


vec3 shadeSkin (vec3 worldPosition, vec3 normal) {
    vec3 albedo = u_skinAlbedo;
    float roughness = 0.3;
    float F0 = 0.35;

    return shadeSurfaceWithLightsWithTransmittance(worldPosition, normal, albedo, roughness, F0);
}

vec3 gammaCorrect (vec3 color) {
    float GAMMA = 2.2;
    return pow(color, vec3(1.0 / GAMMA));
}
