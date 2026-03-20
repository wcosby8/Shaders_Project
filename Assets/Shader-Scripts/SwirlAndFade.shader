Shader "Custom/SwirlAndFade"
{
    Properties
    {
        _MainTex ("Texture 1", 2D) = "white" {} //first image
        _SecondTex ("Texture 2", 2D) = "white" {} //second image
        _Speed ("Speed", Float) = 0.15 //how fast the cycle runs, lower = slower
        _SwirlStrength ("Swirl Strength", Float) = 8.0 //how much rotation at peak
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

            sampler2D _MainTex; //first texture sampler
            float4 _MainTex_ST; //tiling and offset for first texture
            sampler2D _SecondTex; //second texture sampler
            float4 _SecondTex_ST; //tiling and offset for second texture

            float _Speed; //speed property
            float _SwirlStrength; //swirl strength property

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex); //3d to screen space
                o.uv = TRANSFORM_TEX(v.uv, _MainTex); //apply tiling/offset
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float swirlAngle = sin(_Time.y * _Speed) * _SwirlStrength; //continuous sine wave, positive = cw, negative = ccw, never stops

                float2 centeredUV = i.uv - float2(0.5, 0.5); //shift to center so rotation doesnt drift off to the side
                float dist = length(centeredUV); //distance from center

                float angle = swirlAngle / (dist * 3.0 + 0.1); //divide by distance so center spins a lot and edges barely move, the 0.1 prevents divide by zero

                float cosA = cos(angle); //precompute cos so we only do it once
                float sinA = sin(angle); //same for sin

                float2 rotatedUV;
                rotatedUV.x = centeredUV.x * cosA - centeredUV.y * sinA; //rotate x
                rotatedUV.y = centeredUV.x * sinA + centeredUV.y * cosA; //rotate y

                float2 swirlUV = rotatedUV + float2(0.5, 0.5); //shift back to 0-1 space

                float halfCycles = floor((_Time.y * _Speed + UNITY_PI * 0.5) / UNITY_PI); //counts half-cycles, the pi/2 offset makes it tick at peaks not zero crossings
                float whichImage = fmod(halfCycles, 2.0); //0 = image a, 1 = image b, flips every half-cycle

                float halfCycleProgress = frac((_Time.y * _Speed + UNITY_PI * 0.5) / UNITY_PI); //0 to 1 within current half-cycle
                float blend = smoothstep(0.85, 1.0, halfCycleProgress); //stays at 0 for 85% of the cycle then ramps up right at peak

                fixed4 colA = (whichImage < 1.0) ? tex2D(_MainTex, swirlUV) : tex2D(_SecondTex, swirlUV); //current image
                fixed4 colB = (whichImage < 1.0) ? tex2D(_SecondTex, swirlUV) : tex2D(_MainTex, swirlUV); //image we're swapping to

                fixed4 finalColor = lerp(colA, colB, blend); //brief blend near peak so the swap isnt a hard glitch

                return finalColor;
            }
            ENDCG
        }
    }
}
