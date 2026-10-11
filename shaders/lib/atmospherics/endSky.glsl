// Just a Shader: the sky of the End, as deep space.
// A near black sky with cold stars, a band of stars and dust crossing it like the
// Milky Way, four constellations drawn with thin lines (the Eye of Ender, the Enderman,
// the Dragon and the End Crystal), and meteors

float GetEndSkyNoise(vec2 pos) {
    return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
}

// ---------------------------------------------------------------------------------------
// Stars
// ---------------------------------------------------------------------------------------
vec3 GetEndStars(vec3 skyDir, float VdotU) {
    vec3 starCoord = 0.65 * skyDir / (abs(skyDir.y) + length(skyDir.xz));
    vec2 starCoord2 = starCoord.xz * 0.5;
    if (VdotU < 0.0) starCoord2 += 100.0;
    float starFactor = 1024.0;
    starCoord2 = floor(starCoord2 * starFactor) / starFactor;

    float star = 1.0;
    star *= GetEndSkyNoise(starCoord2.xy);
    star *= GetEndSkyNoise(starCoord2.xy + 0.1);
    star *= GetEndSkyNoise(starCoord2.xy + 0.23);
    star = max(star - 0.7, 0.0);
    star *= star;

    // Most stars are cold white, a few lean blue or faintly warm
    float tone = GetEndSkyNoise(starCoord2.xy + 0.41);
    vec3 starColor = mix(vec3(0.60, 0.75, 1.0), vec3(1.0, 0.92, 0.82), smoothstep(0.75, 1.0, tone));

    vec3 endStars = star * starColor * 620.0;

    float absVdotU = abs(VdotU);
    float VdotUM2 = pow2(1.0 - absVdotU);
    endStars *= min(VdotUM2 + 0.015, 0.05) + 0.015;

    // Fewer stars where the End beams stand in front of them
    float VdotUM3 = smoothstep(0.0, 0.25, absVdotU);
    float endBeamHeight = END_BEAM_HEIGHT * 200.0;
    float beamFactor = END_BEAM_INTENSITY * max0(endBeamHeight - abs(END_BEAM_CENTER_ALT - cameraPosition.y)) / endBeamHeight;
    endStars *= pow(VdotUM3, min1(beamFactor + 0.001) * min1(END_BEAM_HEIGHT));

    return endStars * END_STAR_INTENSITY;
}

// ---------------------------------------------------------------------------------------
// The galaxy band
// ---------------------------------------------------------------------------------------
#ifdef END_GALAXY
    vec3 GetEndGalaxy(vec3 skyDir) {
        // The band lies on a tilted circle around the sky. These three axes are fixed:
        // bandNormal points away from the plane of the band, the other two lie in it
        const vec3 bandNormal = vec3(0.5514, 0.4511, -0.7018);
        const vec3 bandX = vec3(0.7863, 0.0, 0.6178);
        vec3 bandY = cross(bandNormal, bandX);

        float offBand = dot(skyDir, bandNormal); // how far this pixel is from the middle of the band
        float band = exp(-pow2(offBand / 0.20));
        if (band < 0.01) return vec3(0.0);

        // Position around the band, from -0.5 to 0.5. It is only ever multiplied by whole
        // numbers before reading the noise texture, so the band has no visible seam
        float around = atan(dot(skyDir, bandY), dot(skyDir, bandX)) / 6.2831853;

        vec2 coord = vec2(around * 4.0, offBand * 0.64);
        vec3 wide = texture2DLod(noisetex, coord, 0.0).rgb;
        vec3 fine = texture2DLod(noisetex, coord * 4.0 + 0.37, 0.0).rgb;
        float dust = wide.r * 0.6 + fine.g * 0.4;

        // Dark lanes of dust running through the middle of the band
        float lanes = smoothstep(0.45, 0.7, texture2DLod(noisetex, vec2(around * 8.0, offBand * 1.27) + 0.71, 0.0).b);
        lanes *= exp(-pow2(offBand / 0.07));

        // The glowing clouds: deep blue shifting to teal, with a few faint magenta patches
        vec3 cloudColor = mix(vec3(0.10, 0.16, 0.42), vec3(0.10, 0.40, 0.48), wide.g);
        cloudColor += vec3(0.40, 0.10, 0.36) * smoothstep(0.6, 0.9, fine.r) * 0.5;
        vec3 galaxy = cloudColor * band * (0.25 + 0.75 * dust) * 0.42;

        // A brighter, warmer bulge at one point of the band, like the centre of a galaxy
        float bulge = exp(-pow2((around - 0.12) / 0.09)) * exp(-pow2(offBand / 0.12));
        galaxy += vec3(0.95, 0.82, 0.70) * bulge * (0.5 + 0.5 * dust) * 0.22;

        galaxy *= 1.0 - 0.75 * lanes;

        // The band is crowded with small stars
        vec2 starCell = floor(vec2(around * 2048.0, offBand * 326.0));
        float starChance = 0.07 * band * (0.4 + 0.6 * dust) * (1.0 - 0.8 * lanes);
        float crowd = step(1.0 - starChance, GetEndSkyNoise(starCell));
        galaxy += crowd * vec3(0.80, 0.88, 1.0) * (0.25 + 0.75 * GetEndSkyNoise(starCell + 0.37)) * 0.55;

        return galaxy;
    }
#endif

// ---------------------------------------------------------------------------------------
// Constellations
// ---------------------------------------------------------------------------------------
#ifdef END_CONSTELLATIONS
    // Every constellation is a list of lines. xy is one end of a line and zw the other,
    // in the constellation's own frame, where the figure fits between -1 and 1.
    // A star is drawn at both ends of every line
    vec4 endConstellationLines[34] = vec4[34](
        // The Eye of Ender: an almond shaped eye with a slit pupil (lines 0 to 8)
        vec4(-1.00,  0.00, -0.50,  0.42),
        vec4(-0.50,  0.42,  0.00,  0.58),
        vec4( 0.00,  0.58,  0.50,  0.42),
        vec4( 0.50,  0.42,  1.00,  0.00),
        vec4( 1.00,  0.00,  0.50, -0.42),
        vec4( 0.50, -0.42,  0.00, -0.58),
        vec4( 0.00, -0.58, -0.50, -0.42),
        vec4(-0.50, -0.42, -1.00,  0.00),
        vec4( 0.00,  0.30,  0.00, -0.30),
        // The Enderman: head, long arms, long legs (lines 9 to 16)
        vec4( 0.00,  1.00,  0.00,  0.70),
        vec4( 0.00,  0.70, -0.35,  0.62),
        vec4( 0.00,  0.70,  0.35,  0.62),
        vec4(-0.35,  0.62, -0.45, -0.25),
        vec4( 0.35,  0.62,  0.45, -0.25),
        vec4( 0.00,  0.70,  0.00,  0.05),
        vec4( 0.00,  0.05, -0.20, -1.00),
        vec4( 0.00,  0.05,  0.20, -1.00),
        // The Dragon: head and neck, body, tail, one raised wing (lines 17 to 25)
        vec4(-1.00,  0.35, -0.60,  0.12),
        vec4(-0.60,  0.12, -0.20,  0.00),
        vec4(-0.20,  0.00,  0.30, -0.05),
        vec4( 0.30, -0.05,  0.70, -0.28),
        vec4( 0.70, -0.28,  1.05, -0.12),
        vec4(-0.20,  0.00, -0.05,  0.75),
        vec4(-0.05,  0.75,  0.60,  0.60),
        vec4( 0.60,  0.60,  0.30, -0.05),
        vec4(-0.05,  0.75,  0.30, -0.05),
        // The End Crystal: a diamond with its inner edges (lines 26 to 33)
        vec4( 0.00,  1.00, -0.60,  0.00),
        vec4( 0.00,  1.00,  0.60,  0.00),
        vec4( 0.00, -1.00, -0.60,  0.00),
        vec4( 0.00, -1.00,  0.60,  0.00),
        vec4(-0.60,  0.00,  0.12, -0.12),
        vec4( 0.12, -0.12,  0.60,  0.00),
        vec4( 0.00,  1.00,  0.12, -0.12),
        vec4( 0.00, -1.00,  0.12, -0.12)
    );

    // Returns x = how much line, y = how much star is on this pixel.
    // centre is where the constellation sits in the sky, size is its half width in radians
    vec2 DrawEndConstellation(vec3 skyDir, vec3 centre, float size, int firstLine, int lineCount) {
        float facing = dot(skyDir, centre);
        if (facing < 0.85) return vec2(0.0);

        // Lay the sky around the centre flat, with "up" pointing towards the top of the sky
        vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), centre));
        vec3 up = cross(centre, right);
        vec2 pos = vec2(dot(skyDir, right), dot(skyDir, up)) / (facing * size);
        if (abs(pos.x) > 1.3 || abs(pos.y) > 1.3) return vec2(0.0);

        float lineWidth = 0.0011 / size;
        float starSize = 0.0045 / size;

        float line = 0.0;
        float star = 0.0;
        for (int i = firstLine; i < firstLine + lineCount; i++) {
            vec2 endA = endConstellationLines[i].xy;
            vec2 endB = endConstellationLines[i].zw;

            vec2 fromA = pos - endA;
            vec2 fromB = pos - endB;
            vec2 alongLine = endB - endA;
            float nearestPoint = clamp(dot(fromA, alongLine) / dot(alongLine, alongLine), 0.0, 1.0);
            float lineDistance = length(fromA - alongLine * nearestPoint);

            line = max(line, exp(-pow2(lineDistance / lineWidth)));
            star = max(star, exp(-dot(fromA, fromA) / (starSize * starSize)));
            star = max(star, exp(-dot(fromB, fromB) / (starSize * starSize)));
        }

        return vec2(line, star);
    }

    vec3 GetEndConstellations(vec3 skyDir) {
        if (skyDir.y < 0.1) return vec3(0.0);

        vec2 drawn = DrawEndConstellation(skyDir, vec3( 0.4801, 0.8134,  0.3285), 0.20, 0, 9)   // the Eye of Ender
                   + DrawEndConstellation(skyDir, vec3(-0.5640, 0.6442,  0.5166), 0.24, 9, 8)   // the Enderman
                   + DrawEndConstellation(skyDir, vec3(-0.4314, 0.7513, -0.4995), 0.30, 17, 9)  // the Dragon
                   + DrawEndConstellation(skyDir, vec3( 0.5238, 0.5646, -0.6378), 0.19, 26, 8); // the End Crystal

        // The lines breathe very slowly, the stars stay steady
        float breathing = 0.75 + 0.25 * sin(frameTimeCounter * 0.4);

        return endCycleTint * drawn.x * 0.16 * breathing // the lines take the current color of the End
             + vec3(0.85, 0.93, 1.0) * drawn.y * 1.6;
    }
#endif

// ---------------------------------------------------------------------------------------
// Everything together
// ---------------------------------------------------------------------------------------
vec3 GetEndSky(vec3 viewPos, float VdotU) {
    vec3 skyDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

    vec3 endSky = endSkyColor;
    endSky += GetEndStars(skyDir, VdotU);

    #ifdef END_GALAXY
        endSky += GetEndGalaxy(skyDir);
    #endif
    #ifdef END_CONSTELLATIONS
        endSky += GetEndConstellations(skyDir);
    #endif
    #ifdef METEORS
        endSky += GetEndMeteors(skyDir, VdotU);
    #endif
    #ifdef END_STORM
        endSky += GetEndLightning(skyDir);
    #endif

    return endSky;
}
