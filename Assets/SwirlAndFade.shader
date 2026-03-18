Shader "Custom/SwirlAndFade"
{
    Properties
    {
        // First image texture - visible on one half of the fade cycle
        _MainTex ("Texture 1", 2D) = "white" {}
        
        // Second image texture - visible on the other half of the fade cycle
        _SecondTex ("Texture 2", 2D) = "white" {}
        
        // _SwirlSpeed controls how fast the swirl animation cycles
        // Lower value = slower, which lets you actually see the image when unswirled
        _SwirlSpeed ("Swirl Speed", Float) = 0.3
        
        // _SwirlStrength controls the maximum rotation amount at the edges
        // Higher = more extreme spiral effect at peak
        _SwirlStrength ("Swirl Strength", Float) = 4.0
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

            float _SwirlSpeed;
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
            // This is where the swirl distortion and cross-fade happen.
            // 
            // KEY CONCEPT - The Swirl:
            // We treat the UV space as a 2D plane. We take each pixel's
            // distance from the center (0.5, 0.5). Pixels far from center
            // get rotated a lot; pixels AT center don't rotate at all.
            // This creates the spiral/swirl look.
            //
            // KEY CONCEPT - The Fade:
            // We use (sin(_Time.y) + 1) * 0.5 to get a 0-to-1 oscillator.
            // The fade and swirl are synchronized so that maximum swirl
            // happens exactly when the blend is 0.5 (mid-crossfade).
            // Each image is fully visible at minimum swirl.
            // -------------------------------------------------------
            fixed4 frag (v2f i) : SV_Target
            {
                // --- SWIRL AMOUNT OVER TIME ---
                // sin(_Time.y * _SwirlSpeed) oscillates between -1 and 1.
                // abs() makes it bounce: 0 -> 1 -> 0 -> 1 (always positive)
                // This means swirl peaks twice per full sin cycle.
                // At abs() = 0, the image is clear. At abs() = 1, max swirl.
                float swirlCycle = abs(sin(_Time.y * _SwirlSpeed));
                
                // Scale the cycle value by our strength constant
                // This is the ANGLE MULTIPLIER for the rotation - more = more twist
                float swirlAmount = swirlCycle * _SwirlStrength;

                // --- DISTANCE FROM CENTER ---
                // Shift UVs so (0.5, 0.5) becomes the origin (0, 0)
                // Now coordinates go from -0.5 to +0.5
                float2 centeredUV = i.uv - float2(0.5, 0.5);
                
                // length() gives us the Euclidean distance from center (0 at center, ~0.7 at corners)
                // Pixels close to center have small dist, pixels at edges have large dist
                float dist = length(centeredUV);

                // --- ROTATION ANGLE PER PIXEL ---
                // The rotation angle = swirl amount * distance from center
                // Center (dist=0): angle = 0, so it never rotates -> stays fixed
                // Edges (dist=0.5+): angle = swirlAmount * 0.5+, rotates a lot
                // This creates the characteristic spiral where edges twist more than center
                float angle = swirlAmount * dist;

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

                // --- SAMPLE BOTH TEXTURES at the swirled UV ---
                // Both textures are distorted by the SAME swirl, so they blend cleanly
                fixed4 col1 = tex2D(_MainTex, swirlUV);
                fixed4 col2 = tex2D(_SecondTex, swirlUV);

                // --- CROSS-FADE BLEND FACTOR ---
                // We want:
                //   - Image 1 fully visible when swirl is low (cycle ~= 0)
                //   - Image 2 fully visible when swirl is low (cycle ~= 0, next wave)
                //   - Crossfade happens DURING maximum swirl so it's hidden by distortion
                //
                // sin oscillates -1 to 1. Adding 1 gives 0 to 2. Multiplying by 0.5 = 0 to 1.
                // This is a smooth oscillator between 0 and 1 that matches our swirl cycle.
                // When blend=0: show texture 1. When blend=1: show texture 2.
                float blend = (sin(_Time.y * _SwirlSpeed) + 1.0) * 0.5;

                // lerp(a, b, t): linearly interpolates from a to b based on t (0 to 1)
                // When blend=0 -> returns col1 fully
                // When blend=1 -> returns col2 fully
                // When blend=0.5 -> 50/50 mix (this is when swirl is at maximum)
                fixed4 finalColor = lerp(col1, col2, blend);

                return finalColor;
            }
            ENDCG
        }
    }
}
