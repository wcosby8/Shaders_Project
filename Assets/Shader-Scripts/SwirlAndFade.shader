Shader "Custom/SwirlAndFade"
{
    Properties
    {
        // First image texture - swirls inward to peak, then hard-cuts to Image B
        _MainTex ("Texture 1", 2D) = "white" {}

        // Second image texture - receives the cut at peak and unswirls back to normal
        _SecondTex ("Texture 2", 2D) = "white" {}

        // _Speed controls how fast the full swirl cycle runs
        // Lower value = slower, giving each image more display time
        _Speed ("Speed", Float) = 0.15

        // _SwirlStrength controls the maximum rotation at the center
        // Higher = tighter, more extreme vortex at peak
        _SwirlStrength ("Swirl Strength", Float) = 8.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;   // 3D vertex position from the mesh
                float2 uv : TEXCOORD0;      // UV texture coordinates (0 to 1)
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;       // UV passed from vertex to fragment shader
                float4 vertex : SV_POSITION; // Screen-space pixel position
            };

            // Declare both textures and their scale/translation data
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _SecondTex;
            float4 _SecondTex_ST;

            float _Speed;
            float _SwirlStrength;

            // -------------------------------------------------------
            // VERTEX SHADER
            // Standard pass-through: convert position to screen space,
            // pass UV coordinates through to the fragment shader.
            // -------------------------------------------------------
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // -------------------------------------------------------
            // FRAGMENT SHADER
            // This is where the tight vortex swirl and hard texture swap happen.
            //
            // KEY CONCEPT - The Continuous Sine Wave:
            // sin(_Time.y * _Speed) runs as one unbroken oscillation — no frac(), no abs().
            // Positive values rotate clockwise; negative values rotate counter-clockwise.
            // The motion never reverses or pauses: it flows through zero and keeps going,
            // giving a fluid, continuously spinning vortex feel.
            //
            // KEY CONCEPT - The Tight Vortex:
            // Unlike a wide swirl (angle = strength * dist), here we use
            // angle = strength * (1 - dist)^2 so pixels CLOSE to the center
            // rotate the most and the effect falls off sharply outward.
            // This creates a tight vortex concentrated at the center point
            // rather than a gentle wide sweep.
            //
            // KEY CONCEPT - The Hard Swap:
            // No lerp, no fade. Swaps fire at BOTH the positive peak AND the negative
            // peak of the sine wave (i.e. every half-cycle), because that is when
            // distortion is maximum and the cut is completely hidden.
            //
            // floor((_Time.y * _Speed + PI/2) / PI) counts completed half-cycles.
            // The + PI/2 phase shift moves the floor threshold to land exactly on each
            // peak (where sin = ±1) rather than on each zero crossing.
            // fmod(..., 2.0) alternates between 0 and 1 on each swap:
            //   0 → show Image A
            //   1 → show Image B
            //
            // Full sequence (one complete A→B→A exchange = two half-cycles):
            //   sin rising  0→+peak : Image A swirls clockwise to peak
            //   +peak                : HARD CUT to Image B (hidden at max distortion)
            //   sin falling +peak→0 : Image B unswirls clockwise back to normal
            //   sin falling 0→-peak : Image B swirls counter-clockwise to negative peak
            //   -peak                : HARD CUT back to Image A (hidden at max distortion)
            //   sin rising  -peak→0 : Image A unswirls counter-clockwise back to normal
            // -------------------------------------------------------
            fixed4 frag (v2f i) : SV_Target
            {
                // --- CONTINUOUS SWIRL ANGLE OVER TIME ---
                // sin(_Time.y * _Speed) is a plain, unbroken sine wave with no frac() or abs().
                // Positive values produce clockwise rotation; negative produce counter-clockwise.
                // The wave passes smoothly through zero (no swirl) twice per full cycle,
                // and through ±1 (peak swirl) twice per full cycle.
                float swirlAngle = sin(_Time.y * _Speed) * _SwirlStrength;

                // --- DISTANCE FROM CENTER ---
                // Shift UVs so (0.5, 0.5) becomes the origin (0, 0)
                // Coordinates now range from -0.5 to +0.5
                float2 centeredUV = i.uv - float2(0.5, 0.5);

                // length() gives Euclidean distance from center
                // (0 at center, ~0.5 at edges, ~0.707 at corners)
                float dist = length(centeredUV);

                // --- ROTATION ANGLE PER PIXEL (VORTEX/DRAIN FALLOFF) ---
                // angle = swirlAngle / (dist * 3.0 + 0.1)
                // Division by distance creates a true vortex: the center spins enormously
                // while the outer edges rotate much less, like water draining from a sink.
                //
                // At center (dist=0):    divisor = 0.1  → angle = swirlAngle * 10  (huge spin)
                // At edge (dist=0.5):    divisor = 1.6  → angle = swirlAngle * 0.625
                // At corner (~dist=0.7): divisor = 2.2  → angle = swirlAngle * 0.455
                //
                // The 0.1 offset prevents division by zero exactly at the center pixel.
                // The sign of swirlAngle carries through, so positive = CW, negative = CCW.
                float angle = swirlAngle / (dist * 3.0 + 0.1);

                // --- 2D ROTATION MATRIX ---
                // To rotate a 2D point by angle theta:
                //   newX = x * cos(theta) - y * sin(theta)
                //   newY = x * sin(theta) + y * cos(theta)
                // We precompute sin and cos for efficiency (only done once per pixel)
                float cosA = cos(angle);
                float sinA = sin(angle);

                // Apply the rotation to the centered UV coordinates
                float2 rotatedUV;
                rotatedUV.x = centeredUV.x * cosA - centeredUV.y * sinA;
                rotatedUV.y = centeredUV.x * sinA + centeredUV.y * cosA;

                // Shift back: add 0.5 to return from centered space to 0-1 UV space
                float2 swirlUV = rotatedUV + float2(0.5, 0.5);

                // --- HARD SWAP AT PEAK SWIRL ---
                // No lerp, no smoothstep, no fade.
                //
                // We need the swap counter to tick at each sine PEAK (sin = ±1),
                // not at each zero crossing. The sine peaks at t*_Speed = PI/2, 3PI/2, 5PI/2...
                // i.e. every PI radians starting from PI/2.
                //
                // floor((_Time.y * _Speed + PI/2) / PI) maps each peak to an integer:
                //   At sin = +1 (t*_Speed = PI/2)  : floor((PI/2 + PI/2) / PI) = floor(1) = 1
                //   At sin = -1 (t*_Speed = 3PI/2) : floor((3PI/2 + PI/2) / PI) = floor(2) = 2
                //   At sin = +1 (t*_Speed = 5PI/2) : floor((5PI/2 + PI/2) / PI) = floor(3) = 3
                // The counter increments by 1 at every peak and stays flat between peaks.
                //
                // fmod(..., 2.0) alternates between 0 and 1 on each increment:
                //   0 → show Image A
                //   1 → show Image B
                //
                // Both textures are sampled at the same swirlUV, so the distortion
                // is identical on both sides of every cut, making it invisible.
                float halfCycles = floor((_Time.y * _Speed + UNITY_PI * 0.5) / UNITY_PI);
                float whichImage = fmod(halfCycles, 2.0);

                // --- BRIEF CROSSFADE WINDOW NEAR PEAK ---
                // frac() of the same half-cycle counter gives how far we are through
                // the current half-cycle: 0.0 at the start, 1.0 at the next peak.
                // smoothstep(0.85, 1.0, ...) returns 0 for the first 85% of the
                // half-cycle, then ramps smoothly 0->1 over the final 15%.
                // This means the blend is sharp for most of the cycle and only
                // briefly softens right as the swirl approaches its peak.
                float halfCycleProgress = frac((_Time.y * _Speed + UNITY_PI * 0.5) / UNITY_PI);
                float blend = smoothstep(0.85, 1.0, halfCycleProgress);

                // colA is the image currently showing; colB is the one about to take over.
                // whichImage determines which texture plays which role this half-cycle.
                fixed4 colA = (whichImage < 1.0) ? tex2D(_MainTex, swirlUV) : tex2D(_SecondTex, swirlUV);
                fixed4 colB = (whichImage < 1.0) ? tex2D(_SecondTex, swirlUV) : tex2D(_MainTex, swirlUV);

                // lerp from colA to colB over the brief window — 0 blend = fully colA,
                // 1 blend = fully colB. At blend=1 (peak) whichImage will have just
                // incremented, so the next half-cycle starts already showing colB cleanly.
                fixed4 finalColor = lerp(colA, colB, blend);

                return finalColor;
            }
            ENDCG
        }
    }
}
