Shader "Custom/SnowAndRoll"{
    Properties{
        _MainTex ("Texture", 2D) = "white" {}
        _RollSpeed ("Roll Speed", Float) = 0.3
        _NoiseStrength ("Noise Strength", Range(0, 2)) = 1.5 //0 = clean, 2 = basically just static
    }

    SubShader{
        Tags { 
            "RenderType"="Opaque" 
        }
        LOD 100

        Pass{
            CGPROGRAM
            #pragma vertex vert //vertex shader
            #pragma fragment frag //fragment shader
            #include "UnityCG.cginc" //unity built in stuff
            struct appdata{ //input per vertex
                float4 vertex : POSITION; //world position
                float2 uv : TEXCOORD0; //uv
            };

            struct v2f{ //vertex to fragment
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _RollSpeed;
            float _NoiseStrength;

            float randomNoise2(float2 seed) {
                float2 magicVec = float2(12.9898, 78.233);//found these numbers on stack overflow, no idea why they work
                float dotVal = dot(seed, magicVec);
                float sinVal = sin(dotVal);
                float big = sinVal * 43758.5453;//this number too, just trust it
                return frac(big);
            }

            v2f vert (appdata v){
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float t = _Time.y;
                float scrollAmt = t * _RollSpeed;
                float rawV = i.uv.y - scrollAmt;  //subtract so it scrolls up not down
                float rolledV = frac(rawV);

            //float rolledV = frac(i.uv.y + scrollAmt); //this went the wrong direction

                float u = i.uv.x;
                float2 rolledUV = float2(u, rolledV);
                fixed4 texColor = tex2D(_MainTex, rolledUV);
                float tick = _Time.y * 30.0; //30fps flicker rate
                float timeTick = floor(tick); //floor so all pixels update at the same time
                float seedX = i.uv.x * 127.1 + timeTick;//big multiplier stops horizontal banding
                float seedY = i.uv.y * 311.7 + timeTick * 1.3;
                float2 noiseSeed = float2(seedX, seedY);

                float n = randomNoise2(noiseSeed);

                float3 noiseColor = float3(n, n, n); //grey, using separate rgb values made it look weird
                float str = _NoiseStrength;
                fixed4 finalColor;
                finalColor.rgb = lerp(texColor.rgb, noiseColor, str);
                float blowout = n * 0.4;//pushes bright spots to white, makes it look more blown out
                finalColor.rgb = lerp(finalColor.rgb, float3(1, 1, 1), blowout);

                finalColor.a = 1.0;

                return finalColor;
            }
            ENDCG
        }
    }
}
