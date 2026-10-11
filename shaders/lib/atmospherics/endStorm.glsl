// Just a Shader: the dry storm of the End.
// There are no clouds. Lightning goes off far away in the void, in every direction,
// above and below, lighting up a patch of the sky for an instant. Some strikes also show
// their bolt: a jagged line with a side branch. The light takes on the current color of
// the End's slow color cycle

float GetEndStormHash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// How far sideways a bolt has wandered at a given distance from its top.
// It runs in straight pieces, each ending at a random offset, which gives the zigzag
float GetEndBoltOffset(float fromTop, float boltLength, float seed) {
    float piece = fromTop / (boltLength * 0.09);
    float pieceSeed = seed + floor(piece) * 1.31;

    float offsetHere = GetEndStormHash(pieceSeed) - 0.5;
    float offsetNext = GetEndStormHash(pieceSeed + 1.31) - 0.5;

    return mix(offsetHere, offsetNext, fract(piece)) * boltLength * 0.16;
}

// A thin bright core inside a faint wide halo
float GetEndBoltGlow(float miss) {
    return exp(-pow2(miss / 0.0022)) + 0.12 * exp(-pow2(miss / 0.02));
}

// A bolt in the flat frame around a strike. It starts above the middle and runs downwards.
// Returns how much of it covers pos
float DrawEndBolt(vec2 pos, float boltLength, float seed) {
    float fromTop = boltLength * 0.5 - pos.y;
    if (fromTop < 0.0 || fromTop > boltLength) return 0.0;

    // The main channel, getting thinner towards its end
    float bolt = GetEndBoltGlow(pos.x - GetEndBoltOffset(fromTop, boltLength, seed))
               * (1.0 - 0.6 * fromTop / boltLength);

    // A side branch that splits off a third of the way down, leans away and dies out quickly
    float forkPoint = boltLength * 0.35;
    float branchLength = boltLength * 0.35;
    float alongBranch = fromTop - forkPoint;
    if (alongBranch > 0.0 && alongBranch < branchLength) {
        float lean = GetEndStormHash(seed + 0.67) < 0.5 ? -0.7 : 0.7;
        float branchX = GetEndBoltOffset(forkPoint, boltLength, seed)
                      + alongBranch * lean
                      + GetEndBoltOffset(alongBranch, boltLength, seed + 53.0) * 0.6;

        bolt += GetEndBoltGlow(pos.x - branchX) * 0.6 * (1.0 - alongBranch / branchLength);
    }

    return bolt;
}

vec3 GetEndLightning(vec3 skyDir) {
    vec3 lightning = vec3(0.0);
    vec3 flashColor = mix(vec3(0.90, 0.95, 1.0), endCycleTint, 0.55);

    // Three independent rhythms that never line up, so the storm does not feel regular
    for (int stream = 0; stream < 3; stream++) {
        float gap = 1.6 + 0.75 * float(stream); // seconds between strikes of this rhythm
        float clock = frameTimeCounter / gap + float(stream) * 0.37;
        float seconds = fract(clock) * gap; // since the strike
        float seed = floor(clock) * 7.0 + float(stream) * 131.0;

        // A strike is over in well under a second, and some beats stay dark
        if (seconds > 0.7 || GetEndStormHash(seed + 0.91) < 0.2) continue;

        // A hard flash with a quick flicker, then a weaker second strike right after
        float brightness = exp(-seconds * 9.0) * (0.65 + 0.35 * sin(seconds * 55.0));
        brightness += 0.6 * exp(-max(seconds - 0.22, 0.0) * 12.0) * step(0.22, seconds);

        // Anywhere around, above or below the horizon, but never straight up or down
        float azimuth = GetEndStormHash(seed + 0.17) * 6.2831853;
        float strikeHeight = GetEndStormHash(seed + 0.59) * 1.7 - 0.85;
        float flatRadius = sqrt(1.0 - strikeHeight * strikeHeight);
        vec3 strikeDir = vec3(cos(azimuth) * flatRadius, strikeHeight, sin(azimuth) * flatRadius);

        float facing = dot(skyDir, strikeDir);
        if (facing < 0.3) continue;

        // Lay the sky around the strike flat, with "up" pointing towards the top of the sky
        vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), strikeDir));
        vec3 up = cross(strikeDir, right);
        vec2 pos = vec2(dot(skyDir, right), dot(skyDir, up)) / facing;

        // The flash: a soft patch of light, uneven like light caught in thin mist
        float size = 0.30 + 0.35 * GetEndStormHash(seed + 0.33);
        float mist = texture2DLod(noisetex, pos * 0.35 + GetEndStormHash(seed + 0.77), 0.0).r;
        float glow = exp(-dot(pos, pos) / (size * size)) * (0.55 + 0.9 * mist);
        lightning += flashColor * glow * brightness * 0.30;

        // Some strikes show their bolt
        if (GetEndStormHash(seed + 0.45) < 0.4) {
            float boltLength = 0.28 + 0.25 * GetEndStormHash(seed + 0.83);
            lightning += mix(vec3(1.0), flashColor, 0.3) * DrawEndBolt(pos, boltLength, seed) * brightness * 3.5;
        }
    }

    return lightning * END_STORM_I;
}
