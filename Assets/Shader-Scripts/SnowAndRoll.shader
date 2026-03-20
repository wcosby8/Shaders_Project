Shader "Custom/SnowAndRoll"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {} //the image
        _RollSpeed ("Roll Speed", Float) = 0.3 //how fast it scrolls up
        _NoiseStrength ("Noise Strength", Range(0, 2)) = 1.5 //0 = no noise, 2 = basically pure static
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
                float4 vertex : POSITION; //vertex position
                float2 uv : TEXCOORD0; //uv coords
            };

            struct v2f
            {
                float2 uv : TEXCOORD0; //uv passed to fragment
                float4 vertex : SV_POSITION; //screen position
            };

            sampler2D _MainTex; //the texture sampler
            float4 _MainTex_ST; //tiling and offset

            float _RollSpeed; //roll speed property
            float _NoiseStrength; //noise strength property

            float randomNoise2(float2 seed)
            {
                return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453); //classic hash, gives a pseudo-random 0-1 value
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex); //3d to screen space
                o.uv = TRANSFORM_TEX(v.uv, _MainTex); //apply tiling/offset
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float rolledV = frac(i.uv.y - _Time.y * _RollSpeed); //scroll the v coord upward over time
                float2 rolledUV = float2(i.uv.x, rolledV); //build the scrolled uv
                fixed4 texColor = tex2D(_MainTex, rolledUV); //sample the texture at the rolled position

                float timeTick = floor(_Time.y * 30.0); //snaps to a new value 30 times per second so the static flickers
                float noise = randomNoise2(float2(i.uv.x * 127.1 + timeTick, i.uv.y * 311.7 + timeTick * 1.3)); //each pixel gets its own random value, the big numbers prevent stripes

                float3 noiseColor = float3(noise, noise, noise); //same value for r g b so its grey static

                fixed4 finalColor;
                finalColor.rgb = lerp(texColor.rgb, noiseColor, _NoiseStrength); //replace the image with static based on strength
                finalColor.rgb = lerp(finalColor.rgb, float3(1, 1, 1), noise * 0.4); //push bright pixels toward white so it looks blown out
                finalColor.a = 1.0; //fully opaque

                return finalColor;
            }
            ENDCG
        }
    }
}
