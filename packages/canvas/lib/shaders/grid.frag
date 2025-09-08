#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

layout(location = 0) uniform vec2 gridSpacing;
layout(location = 2) uniform float lineWidth;
layout(location = 3) uniform vec4 lineColor;
layout(location = 7) uniform float intersectionRadius;
layout(location = 8) uniform vec4 intersectionColor;
layout(location = 12) uniform float zoom;
layout(location = 13) uniform vec2 offset;
// layout(location = 15) uniform vec2 size;

out vec4 fragColor;

// Line antialiasing function
vec2 getLineAlpha(vec2 dist, float lineWidth) {
    float halfWidth = lineWidth * 0.5;
    float pixelRange = 1 / zoom; // Adjust this value to control antialiasing spread

    return vec2(1., 1.) - smoothstep(halfWidth - pixelRange, halfWidth + pixelRange, dist);
}

// Circle antialiasing function
float getCircleAlpha(float dist, float radius) {
    float pixelRange = 1 / zoom; // Adjust this value to control antialiasing spread
    return 1.0 - smoothstep(radius - pixelRange, radius + pixelRange, dist);
}

void main() {
    vec2 canvasCoord = FlutterFragCoord().xy;

    vec2 steps = round(canvasCoord / gridSpacing);

    vec2 lineCoords = steps * gridSpacing;

    vec2 dxdy = abs(canvasCoord - lineCoords);

    vec2 dirAlpha = getLineAlpha(dxdy, lineWidth);

    float dist = distance(canvasCoord, lineCoords);
    float intersectionAlpha = getCircleAlpha(dist, intersectionRadius);

    // Blend colors using the calculated alpha values
    vec4 lineColorWithAlpha = lineColor * max(dirAlpha.x, dirAlpha.y);
    vec4 intersectionColorWithAlpha = intersectionColor * intersectionAlpha;

    // Blend between line and intersection colors
    fragColor = mix(lineColorWithAlpha, intersectionColorWithAlpha, intersectionAlpha);
}