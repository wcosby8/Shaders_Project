Shader "Custom/SnowAndRoll"
{
    Properties
    {
        // _MainTex is the texture slot that appears in the Unity Inspector under "Default Maps"
        // Drag your image onto this slot to assign it
        _MainTex ("Texture", 2D) = "white" {}
        
        // _RollSpeed controls how fast the texture scrolls upward
        // Adjustable in the Inspector - higher = faster roll
        _RollSpeed ("Roll Speed", Float) = 0.3
        
        // _NoiseStrength controls how intense the TV-static noise overlay is
        // 0 = no noise, 1 = full noise overlay
        _NoiseStrength ("Noise Strength", Range(0, 1)) = 0.15
    }

    SubShader
    {
        // "RenderType"="Opaque" means no transparency - solid object
        Tags { "RenderType"="Opaque" }
        LOD 100  // Level of Detail - 100 is standard for simple shaders

        Pass
        {
            CGPROGRAM
            // Tell the GPU which functions are our vertex and fragment shaders
            #pragma vertex vert
            #pragma fragment frag

            // Include Unity's built-in shader helper functions and variables
            // This gives us access to _Time, TRANSFORM_TEX, etc.
            #include "UnityCG.cginc"

            // This struct holds data per VERTEX (corner of a triangle)
            // "appdata" is the input coming FROM Unity's mesh system
            struct appdata
            {
                float4 vertex : POSITION;   // 3D world position of this vertex
                float2 uv : TEXCOORD0;      // UV coordinate (0-1 range, X and Y) for texture mapping
            };

            // This struct is passed FROM the vertex shader TO the fragment shader
            // "v2f" = "vertex to fragment"
            struct v2f
            {
                float2 uv : TEXCOORD0;      // UV coordinate interpolated across the triangle surface
                float4 vertex : SV_POSITION; // Final screen-space position of this pixel
            };

            // Declare the texture and its tiling/offset sampler (Unity pairs these together)
            sampler2D _MainTex;
            float4 _MainTex_ST;  // _ST = Scale and Translation (tiling and offset set in Inspector)

            // Declare our custom properties so the GPU can read them
            float _RollSpeed;
            float _NoiseStrength;

            // -------------------------------------------------------
            // PSEUDO-RANDOM NOISE FUNCTION
            // This classic 30-year-old trick hashes a 2D coordinate into
            // a value between 0 and 1 that looks random to human eyes.
            // The magic numbers (12.9898, 78.233, 43758.5453) are chosen
            // because they produce a chaotic but visually undetectable pattern.
            // -------------------------------------------------------
            float randomNoise2(float2 seed)
            {
                // dot() computes the dot product of the seed with our magic vector
                // sin() of a large dot product gives a chaotic floating point value
                // frac() keeps only the decimal part, giving us 0.0 to 1.0
                return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
            }

            // -------------------------------------------------------
            // VERTEX SHADER
            // Runs once per vertex. Transforms 3D position to screen space
            // and passes UV coordinates along to the fragment shader.
            // -------------------------------------------------------
            v2f vert (appdata v)
            {
                v2f o;
                // UnityObjectToClipPos transforms from object/local space to clip/screen space
                o.vertex = UnityObjectToClipPos(v.vertex);
                // TRANSFORM_TEX applies the tiling and offset from the Inspector to our UVs
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // -------------------------------------------------------
            // FRAGMENT SHADER
            // Runs once per pixel (fragment). This is where the visual magic happens.
            // "i" contains the interpolated data from the vertex shader.
            // Returns the final color of this pixel as fixed4 (R, G, B, Alpha).
            // -------------------------------------------------------
            fixed4 frag (v2f i) : SV_Target
            {
                // --- ROLL EFFECT ---
                // We want the texture to scroll upward continuously.
                // _Time.y is seconds since play started - it increases forever.
                // frac() keeps only the 0-1 fractional part, so the UV wraps
                // back to 0 each time it passes 1, creating a seamless loop.
                // We subtract so the texture moves UP (increasing V = moving down in Unity)
                float rolledV = frac(i.uv.y - _Time.y * _RollSpeed);
                
                // Build a new UV with the original X but the rolled Y
                float2 rolledUV = float2(i.uv.x, rolledV);

                // Sample the texture at our rolled UV position
                // tex2D takes the sampler and the UV coordinate, returns an RGBA color
                fixed4 texColor = tex2D(_MainTex, rolledUV);

                // --- NOISE EFFECT ---
                // We need noise that changes every frame AND varies per pixel.
                // Seed combines: the UV position (so each pixel is different)
                //               + floor(_Time.y * 15) (so it changes ~15 times/sec)
                // floor() is used here so all pixels update simultaneously each frame
                // (without floor, _Time.y would create smooth noise not snowy static)
                float2 noiseSeed = i.uv + floor(_Time.y * 15.0);
                float noise = randomNoise2(noiseSeed); // value between 0 and 1

                // --- NOISE BLENDING ---
                // Raw noise goes from 0 to 1 (black to white).
                // If we just lerp to black or white, the noise disappears against
                // already-dark or already-bright parts of the image.
                // 
                // Solution: remap noise to range from -0.5 to +0.5, then add it.
                // This creates noise that BRIGHTENS dark areas AND DARKENS bright areas,
                // so it's always visible regardless of underlying image content.
                float noiseCentered = (noise - 0.5) * _NoiseStrength * 2.0;
                
                // Add the centered noise to all three color channels equally (gray noise)
                // saturate() clamps the result back to 0-1 range to prevent overflow
                fixed4 finalColor;
                finalColor.rgb = saturate(texColor.rgb + noiseCentered);
                finalColor.a = 1.0; // Fully opaque

                return finalColor;
            }
            ENDCG
        }
    }
}
