Shader "Custom/SwirlAndFade"
{
    Properties {
        _MainTex ("Texture 1", 2D) = "white" {}
        _SecondTex ("Texture 2", 2D) = "white" {}
        _Speed ("Speed", Float) = 0.15 //lower = slower
        _SwirlStrength ("Swirl Strength", Float) = 35.0
    }

    SubShader{
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass{
            CGPROGRAM
            #pragma vertex vert //tells gpu which function is the vertex shader
            #pragma fragment frag //and which is the fragment shader
            #include "UnityCG.cginc" //unity helper stuff, gives us _Time and transforms

            struct appdata{ //data coming in per vertex
                float4 vertex : POSITION; //3d position
                float2 uv : TEXCOORD0; //texture coordinate
            };

            struct v2f{ //what gets passed from vert to frag
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION; //final screen position
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _SecondTex;
            float4 _SecondTex_ST;//idk if i need this one but removing it broke something
            float _Speed;
            float _SwirlStrength;

            v2f vert (appdata v){
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target{
                float thing = _Time.y * _Speed;//time but scaled down
                float val = sin(thing);//gives -1 to 1
                float swirlAngle = val * _SwirlStrength;

                float2 uv2 = i.uv;  //copy of uv so i dont touch the original
                float cx = uv2.x - 0.5;
                float cy = uv2.y - 0.5;
                float2 centeredUV = float2(cx, cy); //shift to center for rotation
                float dx = centeredUV.x;
                float dy = centeredUV.y;
                float dist = sqrt(dx * dx + dy * dy);//length() probably does the same thing but whatever
                float angle = swirlAngle * dist; //center (dist=0) doesnt rotate at all, edges rotate the most
                float cosA = cos(angle);
                float sinA = sin(angle);

             // tried doing this in one line, kept getting it wrong
                float rx = dx * cosA - dy * sinA;
                float ry = dx * sinA + dy * cosA;
                float2 rotatedUV = float2(rx, ry);
                float2 swirlUV = rotatedUV + float2(0.5, 0.5); //shift back

                //float2 swirlUV = rotatedUV + 0.5; //this doesnt work in hlsl for some reason
                float timeScaled = _Time.y * _Speed; //same as thing up top, forgot i had it
                float shifted = timeScaled + UNITY_PI * 0.5; //phase shift so counter ticks at peaks
                float divided = shifted / UNITY_PI;
                float halfCycles = floor(divided);//how many half cycles done
                float whichImage = fmod(halfCycles, 2.0);//0 or 1
                float prog = frac(divided);
                float blend = smoothstep(0.85, 1.0, prog); //only blend near peak, took forever to tune this value
                fixed4 colA = (whichImage < 1.0) ? tex2D(_MainTex, swirlUV) : tex2D(_SecondTex, swirlUV);
                fixed4 colB = (whichImage < 1.0) ? tex2D(_SecondTex, swirlUV) : tex2D(_MainTex, swirlUV);
                fixed4 finalColor = lerp(colA, colB, blend);

                return finalColor;
            }
            ENDCG
        }
    }
}
