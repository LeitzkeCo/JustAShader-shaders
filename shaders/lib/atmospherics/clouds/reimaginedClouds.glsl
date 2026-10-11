#include "/lib/atmospherics/clouds/cloudCoord.glsl"

// Just a Shader: clouds built as stacked steps. The cloud texture only says "cloud" or
// "no cloud" for each cell, so height comes from stacking layers: every layer up, the
// footprint steps inwards, which gives a flat base and a stepped dome on top
const float cloudStretch = 4.0; // the flat base sits this far below the cloud altitude
const float cloudRise = float(CLOUD_RISE); // total height of the tallest clouds
const float cloudLayerHeight = 8.0; // height of one step
const float cloudStepInset = 0.5; // how far each step moves inwards, in cloud cells
const float cloudTallness = cloudRise * 0.7;
const float cloudRoundness = 0.125;

float Get2DCloudSample(vec2 pos) {
    #ifdef DEFERRED1
        return texture2D(colortex3, GetRoundedCloudCoord(pos, cloudRoundness)).b;
    #else
        return texture2D(gaux4, GetRoundedCloudCoord(pos, cloudRoundness)).b;
    #endif
}

bool GetCloudNoise(vec3 tracePos, inout vec3 tracePosM, int cloudAltitude) {
    tracePosM = ModifyTracePos(tracePos, cloudAltitude);

    float height = tracePos.y - (float(cloudAltitude) - cloudStretch);
    if (height < 0.0 || height >= cloudRise) return false;

    if (Get2DCloudSample(tracePosM.xz) < 0.5) return false;

    // The bottom layer is the full footprint. Higher layers only exist where there is
    // still cloud this far away in every direction, so each one is smaller than the last
    float inset = floor(height / cloudLayerHeight) * cloudStepInset;
    if (inset < 0.01) return true;

    float nearestGap = min(min(Get2DCloudSample(tracePosM.xz + vec2( inset, 0.0)),
                               Get2DCloudSample(tracePosM.xz + vec2(-inset, 0.0))),
                           min(Get2DCloudSample(tracePosM.xz + vec2(0.0,  inset)),
                               Get2DCloudSample(tracePosM.xz + vec2(0.0, -inset))));
    return nearestGap > 0.5;
}

vec4 GetVolumetricClouds(int cloudAltitude, float distanceThreshold, inout float cloudLinearDepth, float skyFade, float skyMult0, vec3 cameraPos, vec3 nPlayerPos, float lViewPosM, float VdotS, float VdotU, float dither) {
    vec4 volumetricClouds = vec4(0.0);

    float lowerPlaneAltitude  = cloudAltitude - cloudStretch;
    float higherPlaneAltitude = lowerPlaneAltitude + cloudRise;

    float lowerPlaneDistance  = (lowerPlaneAltitude - cameraPos.y) / nPlayerPos.y;
    float higherPlaneDistance = (higherPlaneAltitude - cameraPos.y) / nPlayerPos.y;
    float minPlaneDistance = min(lowerPlaneDistance, higherPlaneDistance);
          minPlaneDistance = max(minPlaneDistance, 0.0);
    float maxPlaneDistance = max(lowerPlaneDistance, higherPlaneDistance);
    if (maxPlaneDistance < 0.0) return vec4(0.0);
    float planeDistanceDif = maxPlaneDistance - minPlaneDistance;

    float aboveClouds = clamp01((cameraPos.y - lowerPlaneAltitude) * 0.05);
    float skyFadeM = mix(skyFade, 1.0, 0.4 * max(aboveClouds, rainFactor2));

    // Step small enough to land inside every layer and not to stride over a whole step sideways
    #if CLOUD_QUALITY == 1 || !defined DEFERRED1
        const float maxStepLength = 16.0;
        const int maxSampleCount = 32;
    #elif CLOUD_QUALITY == 2
        const float maxStepLength = 10.0;
        const int maxSampleCount = 64;
    #elif CLOUD_QUALITY == 3
        const float maxStepLength = 5.0;
        const int maxSampleCount = 128;
    #endif
    float stepLength = min(0.5 * cloudLayerHeight / max(abs(nPlayerPos.y), 0.0001), maxStepLength);
    int sampleCount = clamp(int(planeDistanceDif / stepLength) + 1, 8, maxSampleCount);

    float stepMult = planeDistanceDif / sampleCount;
    vec3 traceAdd = nPlayerPos * stepMult;
    vec3 tracePos = cameraPos + minPlaneDistance * nPlayerPos;
    tracePos += traceAdd * dither;
    tracePos.y -= traceAdd.y;

    #ifdef FIX_AMD_REFLECTION_CRASH
        sampleCount = min(sampleCount, 30); //BFARC
    #endif

    for (int i = 0; i < sampleCount; i++) {
        tracePos += traceAdd;

        vec3 cloudPlayerPos = tracePos - cameraPos;
        float lTracePos = length(cloudPlayerPos);
        float lTracePosXZ = length(cloudPlayerPos.xz);
        float cloudMult = 1.0;
        if (lTracePosXZ > distanceThreshold) break;
        if (lTracePos > lViewPosM) {
            if (skyFade < 0.7) continue;
            else cloudMult = skyMult0;
        }

        vec3 tracePosM;
        if (GetCloudNoise(tracePos, tracePosM, cloudAltitude)) {
            float lightMult = 1.0;

            #if SHADOW_QUALITY > -1 && !defined VOXY_PATCH
                float shadowLength = shadowDistance * 0.9166667; //consistent08JJ622
                if (shadowLength > lTracePos)
                if (GetShadowOnCloud(tracePos, cameraPos, cloudAltitude, lowerPlaneAltitude, higherPlaneAltitude)) {
                    #ifdef CLOUD_CLOSED_AREA_CHECK
                        if (eyeBrightness.y != 240) continue;
                        else
                    #endif
                    lightMult = 0.25;
                }
            #endif

            float cloudHeight = tracePos.y - lowerPlaneAltitude;
            float cloudShading = cloudHeight / cloudTallness; // dark belly, bright tops
                  cloudShading = pow(clamp01(cloudShading), 0.8);
                  // every step is a little darker near its foot, so the stack reads clearly
                  cloudShading *= 0.86 + 0.14 * fract(cloudHeight / cloudLayerHeight);
            float VdotSM1 = max0(sunVisibility > 0.5 ? VdotS : - VdotS);

            #if CLOUD_QUALITY >= 2
                #ifdef DEFERRED1
                    float cloudShadingM = 1.0 - pow2(cloudShading);
                #else
                    float cloudShadingM = 1.0 - cloudShading;
                #endif

                float gradientNoise = InterleavedGradientNoiseForClouds();

                vec3 cLightPos = tracePosM;
                vec3 cLightPosAdd = normalize(ViewToPlayer(lightVec * 1000000000.0)) * vec3(0.08);
                cLightPosAdd *= shadowTime;

                float light = 2.0;
                cLightPos += (1.0 + gradientNoise) * cLightPosAdd;
                    light -= Get2DCloudSample(cLightPos.xz) * cloudShadingM;
                cLightPos += gradientNoise * cLightPosAdd;
                    light -= Get2DCloudSample(cLightPos.xz) * cloudShadingM;

                float VdotSM2 = VdotSM1 * shadowTime * 0.25;
                      VdotSM2 += 0.5 * cloudShading + 0.08;
                cloudShading = VdotSM2 * light * lightMult;
            #endif

            vec3 colorSample = cloudAmbientColor * 0.95 * (1.0 - 0.35 * cloudShading) + cloudLightColor * 0.9 * (0.1 + cloudShading);

            // Sunrise and sunset paint the clouds by height: gold on the tops, mauve in the bellies
            float cloudHeightFactor = clamp01(cloudHeight / cloudRise);
            float goldenHourTint = invNoonFactor * sunVisibility2 * invRainFactor * 0.8;
            vec3 heightTint = mix(vec3(0.80, 0.72, 1.02), vec3(1.14, 0.98, 0.84), cloudHeightFactor);
            colorSample *= mix(vec3(1.0), heightTint, goldenHourTint);
            vec3 cloudSkyColor = GetSky(VdotU, VdotS, dither, isEyeInWater == 0, false);
            #ifdef ATM_COLOR_MULTS
                cloudSkyColor *= sqrtAtmColorMult; // C72380KD - Reduced atmColorMult impact on some things
            #endif
            float distanceRatio = (distanceThreshold - lTracePosXZ) / distanceThreshold;
            float cloudFogFactor = pow2(clamp(distanceRatio, 0.0, 1.0)) * 0.707;
            cloudFogFactor = mix(1.0, cloudFogFactor, skyFadeM);
            colorSample *= 1.0 - 0.2 * (1.0 - skyFadeM) * max(sunVisibility2, nightFactor);
            colorSample = mix(cloudSkyColor, colorSample, cloudFogFactor * 0.707);
            colorSample *= pow2(1.0 - maxBlindnessDarkness);

            float cloudDistanceFactor = clamp(distanceRatio, 0.0, 0.75);

            volumetricClouds.a = sqrt(cloudDistanceFactor * 1.33333) * cloudMult;
            volumetricClouds.rgb = colorSample;

            cloudLinearDepth = sqrt(lTracePos / renderDistance);
            break;
        }
    }

    volumetricClouds.a *= 0.5 + 0.5 * skyFadeM;

    return volumetricClouds;
}
