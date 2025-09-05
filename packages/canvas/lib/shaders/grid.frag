#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 gridSpacing;
uniform float lineWidth;
uniform vec4 lineColor;
uniform float intersectionRadius;
uniform vec4 intersectionColor;

out vec4 fragColor;

// Line antialiasing function
vec2 getLineAlpha(vec2 dist, float lineWidth) {
    float halfWidth = lineWidth * 0.5;
    float pixelRange = 1.0; // Adjust this value to control antialiasing spread

    return vec2(1., 1.) - smoothstep(halfWidth - pixelRange, halfWidth + pixelRange, dist);
}

// Circle antialiasing function
float getCircleAlpha(float dist, float radius) {
    float pixelRange = 1.0; // Adjust this value to control antialiasing spread
    return 1.0 - smoothstep(radius - pixelRange, radius + pixelRange, dist);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    vec2 steps = round(fragCoord / gridSpacing);

    vec2 lineCoords = steps * gridSpacing;

    vec2 dxdy = abs(fragCoord - lineCoords);

    vec2 dirAlpha = getLineAlpha(dxdy, lineWidth);

    float dist = distance(fragCoord, lineCoords);
    float intersectionAlpha = getCircleAlpha(dist, intersectionRadius);

    // Blend colors using the calculated alpha values
    vec4 lineColorWithAlpha = lineColor * max(dirAlpha.x, dirAlpha.y);
    vec4 intersectionColorWithAlpha = intersectionColor * intersectionAlpha;

    // Blend between line and intersection colors
    fragColor = mix(lineColorWithAlpha, intersectionColorWithAlpha, intersectionAlpha);
}