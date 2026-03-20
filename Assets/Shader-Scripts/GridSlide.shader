Shader "Custom/GridSlide"{
    Properties{
        _MainTex ("Texture", 2D) = "white" {}
        _GridSize ("Grid Size", Float) = 4.0 //4 = 4x4 grid
        _PhaseSpeed ("Phase Speed", Float) = 0.7
        _SlideAmount ("Slide Amount", Float) = 1.0 //1.0 = slides exactly one tile
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
            #include "UnityCG.cginc" //gives us _Time, transforms, etc
            struct appdata{ //per vertex input
                float4 vertex : POSITION; //3d position
                float2 uv : TEXCOORD0;
            };

            struct v2f{ //passed from vert to frag
    
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION; //screen space position
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _GridSize;
            float _PhaseSpeed;
            float _SlideAmount;

            v2f vert (appdata v){
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target{
                float2 scaled = i.uv * _GridSize;//scale up so we can work in tile space
                float cx = floor(scaled.x); //tile column
                float cy = floor(scaled.y); //tile row
                float2 cellCoord = float2(cx, cy);
                float lx = frac(scaled.x); //position within tile 0-1
                float ly = frac(scaled.y);
                float2 localUV = float2(lx, ly);
                float pt = _Time.y * _PhaseSpeed;
                float phaseRaw = fmod(floor(pt), 4.0);//0 1 2 3 then repeats
                int phase = (int)phaseRaw;
                float slideT = frac(pt);  //progress within current phase
                float rowCheck = fmod(cy, 2.0);
                float dirX = (rowCheck < 1.0) ? 1.0 : -1.0;//alternates per row
                float colCheck = fmod(cx, 2.0);
                float dirY = (colCheck < 1.0) ? 1.0 : -1.0; //alternates per column
                float ox = 0.0;
                float oy = 0.0;

                if(phase == 0){
                    ox = dirX * slideT * _SlideAmount; //slides out horizontally
                    oy = 0.0;
                }
                else if(phase == 1){
                    ox = dirX * _SlideAmount; //x stays put
                    oy = dirY * slideT * _SlideAmount;//now y slides out
                }
                else if (phase == 2){
                    float returning = 1.0 - slideT; //flip it so it goes back
                    ox = dirX * returning * _SlideAmount;
                    oy = dirY * _SlideAmount; //y still held
                }
                else{
                //phase 3, everything coming home
                    float returning = 1.0 - slideT;
                    ox = 0.0;
                    oy = dirY * returning * _SlideAmount;
                }

                float2 offset = float2(ox, oy);
                float2 combined = cellCoord + localUV + offset;
                float2 normalized = combined / _GridSize;  //back to 0-1 range
                float2 finalUV = frac(normalized);//wrap edges

                 //float2 finalUV = (cellCoord + localUV + offset) / _GridSize; //this version doesnt wrap correctly

                fixed4 col = tex2D(_MainTex, finalUV);

                float thick = 0.03;
                float edgeLeft = lx;
                float edgeRight = 1.0 - lx;
                float edgeBottom = ly;
                float edgeTop = 1.0 - ly;

                if(edgeLeft < thick || edgeRight < thick || edgeBottom < thick || edgeTop < thick){
                    col.rgb *= 0.6; //darken borders
                }

                return col;
            }
            ENDCG
        }
    }
}
