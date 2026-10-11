// Just a Shader: a pixel art highlight on the exposed edges of blocks.
//
// The highlight is drawn in whole texture pixels: the rows of block texture pixels that
// touch an exposed edge get brighter, all by the same amount. It looks as if it was
// painted into the texture, keeps its size at any distance and never cuts through the
// middle of a texture pixel.
//
// For every pixel we find the block face it is on, snap to the centre of its texture
// pixel, then look a few texture pixels to each side along the face. If the face is still
// there, nothing happens. If there is open air instead, we are next to an exposed edge.
// Flat ground made of many blocks stays clean, and so do inner corners.
//
// Only pixels flagged by gbuffers_terrain as plain solid blocks get here, which keeps
// plants, leaves, mobs and glowing blocks out

// Is there open air where this face would be, at the given point of its plane?
// planeNormalView and planeOffset describe the face plane in view space
bool IsOutlineEdge(vec3 planePoint, vec3 planeNormalView, float planeOffset) {
    vec3 pointView = mat3(gbufferModelView) * (planePoint - gbufferModelViewInverse[3].xyz);
    vec4 pointClip = gbufferProjection * vec4(pointView, 1.0);
    if (pointClip.w < 0.05) return false;

    vec2 coord = pointClip.xy / pointClip.w * 0.5 + 0.5;
    if (coord.x < 0.0 || coord.x > 1.0 || coord.y < 0.0 || coord.y > 1.0) return false;

    // Compare against the exact spot where the centre of that screen pixel meets the face
    // plane. Comparing against the point itself would be off by up to half a pixel, which
    // is a lot of depth on a surface seen at a shallow angle
    ivec2 pixel = ivec2(coord * view);
    vec2 pixelCoord = (vec2(pixel) + 0.5) / view;
    vec3 actualView = ScreenToView(vec3(pixelCoord, texelFetch(depthtex0, pixel, 0).r));
    float actualDepth = -actualView.z;
    if (actualDepth < 0.05) return false;

    float slope = dot(planeNormalView, actualView / actualDepth);
    if (abs(slope) < 0.0001) return false;

    float expectedDepth = planeOffset / slope;
    if (expectedDepth < 0.05) return false;

    float tolerance = 0.004 + expectedDepth * expectedDepth * 0.0000025; // depth buffer precision
    return actualDepth > expectedDepth + tolerance;
}

void DoBlockOutline(inout vec3 color, float z0, vec3 playerPos, float lViewPos) {
    const float fadeStart = 28.0;
    const float fadeEnd = 56.0;
    if (lViewPos > fadeEnd) return;

    // Which way does this face point? Take the slope of the depth buffer around the pixel,
    // each time using the neighbour on the same surface, so the answer stays right on the
    // last pixel before an edge
    vec2 pixelSize = 1.0 / view;
    vec3 posC = ScreenToView(vec3(texCoord, z0));
    vec3 posL = ScreenToView(vec3(texCoord - vec2(pixelSize.x, 0.0), texelFetch(depthtex0, texelCoord + ivec2(-1,  0), 0).r));
    vec3 posR = ScreenToView(vec3(texCoord + vec2(pixelSize.x, 0.0), texelFetch(depthtex0, texelCoord + ivec2( 1,  0), 0).r));
    vec3 posD = ScreenToView(vec3(texCoord - vec2(0.0, pixelSize.y), texelFetch(depthtex0, texelCoord + ivec2( 0, -1), 0).r));
    vec3 posU = ScreenToView(vec3(texCoord + vec2(0.0, pixelSize.y), texelFetch(depthtex0, texelCoord + ivec2( 0,  1), 0).r));

    vec3 acrossX = abs(posL.z - posC.z) < abs(posR.z - posC.z) ? posC - posL : posR - posC;
    vec3 acrossY = abs(posD.z - posC.z) < abs(posU.z - posC.z) ? posC - posD : posU - posC;

    vec3 faceNormal = abs(mat3(gbufferModelViewInverse) * normalize(cross(acrossX, acrossY)));
    float strongest = max(faceNormal.x, max(faceNormal.y, faceNormal.z));
    if (strongest < 0.95) return; // not a face that follows the block grid

    vec3 normalAxis = vec3(greaterThanEqual(faceNormal, vec3(strongest)));
    vec3 sideA = normalAxis.x > 0.5 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 sideB = normalAxis.z > 0.5 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);

    // Snap to the centre of the texture pixel, but only along the face. Across the face
    // the position stays exactly where the depth buffer put it
    vec3 cameraFract = fract(cameraPosition);
    vec3 blockSpacePos = playerPos + cameraFract;
    vec3 texelCentre = (floor(blockSpacePos * 16.0) + 0.5) / 16.0;
    vec3 snappedPos = mix(texelCentre, blockSpacePos, normalAxis) - cameraFract;

    vec3 planeNormalView = mat3(gbufferModelView) * normalAxis;
    float planeOffset = dot(planeNormalView, mat3(gbufferModelView) * (snappedPos - gbufferModelViewInverse[3].xyz));

    float reach = float(BLOCK_OUTLINE_THICKNESS) / 16.0;
    bool onEdge = IsOutlineEdge(snappedPos + sideA * reach, planeNormalView, planeOffset)
               || IsOutlineEdge(snappedPos - sideA * reach, planeNormalView, planeOffset)
               || IsOutlineEdge(snappedPos + sideB * reach, planeNormalView, planeOffset)
               || IsOutlineEdge(snappedPos - sideB * reach, planeNormalView, planeOffset);

    // Where the outline turns a corner inwards (an L shaped group of faces), the texture
    // pixels in the elbow only see the open air diagonally. Without this the outline
    // would stop short on both sides and leave a notch in the corner
    if (!onEdge) {
        onEdge = IsOutlineEdge(snappedPos + (sideA + sideB) * reach, planeNormalView, planeOffset)
              || IsOutlineEdge(snappedPos + (sideA - sideB) * reach, planeNormalView, planeOffset)
              || IsOutlineEdge(snappedPos - (sideA - sideB) * reach, planeNormalView, planeOffset)
              || IsOutlineEdge(snappedPos - (sideA + sideB) * reach, planeNormalView, planeOffset);
    }
    if (!onEdge) return;

    float fade = 1.0 - smoothstep(fadeStart, fadeEnd, lViewPos);
    color += color * BLOCK_OUTLINE_I * fade;
}
