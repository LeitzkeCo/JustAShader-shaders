// Just a Shader: meteors.
//
// Overworld: on clear nights one meteor every 17 to 33 seconds.
// The End: the same steady trickle, plus a meteor shower every three minutes, when for
// about 24 seconds meteors streak out of one point of the sky one after another.
//
// Time is cut into slots and each slot launches one meteor. Everything about a meteor
// (where it starts, where it is heading, how rare it is) is derived from the number of
// its slot, so no state has to be kept between frames.
//
// Rarity, per meteor:
//   about 40% blue-green, about 40% golden
//   6% each: violet, crimson, emerald
//   1 in 60 (roughly once every three nights): the pink one. Much brighter, slower,
//   crossing far more sky, and its trail stays glowing for several seconds after it passed

float GetMeteorHash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// A unit vector from a compass angle and a height above the horizon, both in radians
vec3 GetMeteorSkyPoint(float azimuth, float elevation) {
    return vec3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation));
}

// One meteor. origin is where it appears, travel is the direction it flies in (it must be
// at a right angle to origin), seconds is the time since it was launched
vec3 DrawMeteor(vec3 skyDir, vec3 origin, vec3 travel, float seconds, float rarity) {
    bool pinkOne = rarity < 0.0167;

    float flightTime = pinkOne ? 4.0 : 1.8;  // seconds the head is flying
    float arcLength  = pinkOne ? 0.95 : 0.5; // how much sky it crosses, in radians
    float lingerTime = pinkOne ? 7.0 : 0.0;  // seconds the trail keeps glowing afterwards
    if (seconds < 0.0 || seconds > flightTime + lingerTime) return vec3(0.0);

    // The path is an arc from the origin towards the heading. Measure this pixel against
    // it: the angle along the arc, and how far off to the side of the arc it is
    float towardsOrigin = dot(skyDir, origin);
    if (towardsOrigin <= 0.0) return vec3(0.0);
    float pathAngle = atan(dot(skyDir, travel), towardsOrigin);
    float aside = abs(dot(skyDir, cross(origin, travel)));

    float flight = min(seconds / flightTime, 1.0);
    float headAngle = flight * arcLength;
    float behind = headAngle - pathAngle; // angle behind the head, positive on the trail
    float headDistance2 = behind * behind + aside * aside;

    if (!pinkOne) {
        float life = sin(flight * 3.14159265); // fades in, then burns out

        // Tail: long, widest at the head and thinning to nothing
        float tailLength = 0.02 + 0.22 * life;
        float along = clamp(behind / tailLength, 0.0, 1.0);
        float tailWidth = mix(0.0035, 0.0008, along);
        float tail = float(behind > 0.0 && behind < tailLength) * pow2(1.0 - along) * exp(-pow2(aside / tailWidth));

        float headGlow = exp(-headDistance2 / (0.006 * 0.006));

        vec3 tailColor = rarity < 0.0767 ? vec3(0.62, 0.42, 1.0)   // violet
                       : rarity < 0.1367 ? vec3(1.0, 0.32, 0.22)   // crimson
                       : rarity < 0.1967 ? vec3(0.32, 1.0, 0.45)   // emerald
                       : rarity < 0.6    ? vec3(0.55, 1.0, 0.9)    // blue-green
                       :                   vec3(1.0, 0.8, 0.5);    // golden

        return (tail * tailColor * 1.2 + headGlow * vec3(1.0, 0.97, 0.9) * 2.2) * life;
    }

    // The pink one. Every point of its trail remembers when the head went through it,
    // and fades from then on
    float age = seconds - pathAngle / arcLength * flightTime;
    float onTrail = smoothstep(0.0, 0.02, pathAngle) * float(behind > 0.0);

    float trailWidth = 0.004 + 0.0025 * min(age, 4.0); // spreads out as it cools
    float trail = onTrail * exp(-max(age, 0.0) / 2.2) * exp(-pow2(aside / trailWidth));
    vec3 trailColor = mix(vec3(1.0, 0.32, 0.72), vec3(1.0, 0.86, 0.95), exp(-max(age, 0.0) * 3.0)); // white hot, then pink

    // The head: a hard bright core inside a wide pink halo, gone once the flight is over
    float burning = min(seconds / 0.3, 1.0) * float(seconds < flightTime) * (1.0 - pow2(pow2(flight)));
    float headCore = exp(-headDistance2 / (0.012 * 0.012));
    float headHalo = exp(-headDistance2 / (0.05 * 0.05));

    return trail * trailColor * 2.5
         + (headCore * vec3(1.0, 0.95, 0.98) * 6.0 + headHalo * vec3(1.0, 0.4, 0.75) * 0.6) * burning;
}

// The steady trickle: one meteor per slot, from a random spot, falling towards the horizon
vec3 DrawLoneMeteor(vec3 skyDir) {
    const float slotLength = 25.0; // seconds

    float slotTime = frameTimeCounter / slotLength;
    float slot = floor(slotTime);
    float seconds = fract(slotTime) * slotLength - GetMeteorHash(slot + 0.37) * 8.0; // since launch
    if (seconds < 0.0 || seconds > 11.0) return vec3(0.0);

    vec3 origin = GetMeteorSkyPoint(GetMeteorHash(slot) * 6.2831853, mix(0.5, 1.15, GetMeteorHash(slot + 0.11)));

    float heading = GetMeteorHash(slot + 0.73) * 6.2831853;
    vec3 travel = normalize(cross(origin, vec3(cos(heading), 0.0, sin(heading))));
    if (travel.y > 0.0) travel = -travel;

    return DrawMeteor(skyDir, origin, travel, seconds, GetMeteorHash(slot + 0.51));
}

vec3 GetMeteors(vec3 viewPos, float VdotU) {
    float night = (1.0 - sunVisibility) * invRainFactor;
    if (night < 0.01 || VdotU < 0.02) return vec3(0.0);

    vec3 skyDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

    return DrawLoneMeteor(skyDir) * night * min1(VdotU * 4.0) * METEOR_I;
}

#ifdef END
    // A shower: meteors launched in quick succession, all flying away from one point of the sky
    vec3 DrawMeteorShower(vec3 skyDir) {
        const float showerPeriod = 180.0; // seconds from one shower to the next
        const float showerLength = 24.0;  // seconds a shower lasts
        const float launchGap = 1.3;      // seconds between its meteors

        float showerClock = frameTimeCounter / showerPeriod;
        float shower = floor(showerClock);
        float showerSeconds = fract(showerClock) * showerPeriod;
        if (showerSeconds > showerLength + 3.0) return vec3(0.0);

        vec3 radiant = GetMeteorSkyPoint(GetMeteorHash(shower + 0.19) * 6.2831853, mix(0.6, 1.2, GetMeteorHash(shower + 0.43)));
        float newest = floor(showerSeconds / launchGap);

        // A meteor flies for longer than the gap, so the newest one and the one before it overlap
        vec3 meteors = vec3(0.0);
        for (int i = 0; i < 2; i++) {
            float launch = newest - float(i);
            if (launch < 0.0 || launch * launchGap > showerLength) continue;

            float seed = shower * 37.0 + launch;
            if (GetMeteorHash(seed + 0.61) < 0.25) continue; // an uneven rhythm, some launches are skipped

            vec3 scatter = vec3(GetMeteorHash(seed + 0.13), GetMeteorHash(seed + 0.29), GetMeteorHash(seed + 0.47)) * 2.0 - 1.0;
            vec3 origin = normalize(radiant + scatter * 0.45);
            vec3 away = origin * dot(origin, radiant) - radiant;
            if (dot(away, away) < 0.0001) continue;

            // Showers bring the common and the rare colors, never the pink one
            float rarity = 0.02 + 0.98 * GetMeteorHash(seed + 0.51);
            meteors += DrawMeteor(skyDir, origin, normalize(away), showerSeconds - launch * launchGap, rarity);
        }
        return meteors;
    }

    vec3 GetEndMeteors(vec3 skyDir, float VdotU) {
        if (VdotU < 0.02) return vec3(0.0);

        return (DrawLoneMeteor(skyDir) + DrawMeteorShower(skyDir)) * min1(VdotU * 4.0) * METEOR_I;
    }
#endif
