Shader "Custom/GridSlide"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {} //the image
        _GridSize ("Grid Size", Float) = 4.0 //how many tiles across, 4 means 4x4
        _PhaseSpeed ("Phase Speed", Float) = 0.7 //how fast the phases cycle
        _SlideAmount ("Slide Amount", Float) = 1.0 //how far each tile moves, 1.0 = one full tile
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
            float4 _MainTex_ST; //tiling and offset data
            float _GridSize; //grid size property
            float _PhaseSpeed; //phase speed property
            float _SlideAmount; //slide amount property

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex); //3d to screen space
                o.uv = TRANSFORM_TEX(v.uv, _MainTex); //apply tiling/offset
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 scaledUV = i.uv * _GridSize; //scale uv up so each tile is its own 0-1 space
                float2 cellCoord = floor(scaledUV); //which tile we're in
                float2 localUV = frac(scaledUV); //position within that tile

                float phaseTime = _Time.y * _PhaseSpeed; //time scaled to phase speed
                int phase = (int)fmod(floor(phaseTime), 4.0); //which of the 4 phases we're in
                float slideT = frac(phaseTime); //0 to 1 progress through current phase

                float dirX = (fmod(cellCoord.y, 2.0) < 1.0) ? 1.0 : -1.0; //even rows go right, odd go left
                float dirY = (fmod(cellCoord.x, 2.0) < 1.0) ? 1.0 : -1.0; //even cols go up, odd go down

                float2 offset = float2(0.0, 0.0); //start with no offset

                if (phase == 0)
                {
                    offset.x = dirX * slideT * _SlideAmount; //x slides out
                    offset.y = 0.0; //y not doing anything yet
                }
                else if (phase == 1)
                {
                    offset.x = dirX * _SlideAmount; //x stays displaced
                    offset.y = dirY * slideT * _SlideAmount; //y slides out now
                }
                else if (phase == 2)
                {
                    offset.x = dirX * (1.0 - slideT) * _SlideAmount; //x coming back
                    offset.y = dirY * _SlideAmount; //y still displaced
                }
                else // phase == 3
                {
                    offset.x = 0.0; //x is back home
                    offset.y = dirY * (1.0 - slideT) * _SlideAmount; //y coming back
                }

                float2 finalUV = frac((cellCoord + localUV + offset) / _GridSize); //add offset, wrap, normalize back to 0-1
                fixed4 col = tex2D(_MainTex, finalUV); //sample the texture

                float lineThickness = 0.03; //how thick the grid lines are
                if (localUV.x < lineThickness || localUV.x > (1.0 - lineThickness) ||
                    localUV.y < lineThickness || localUV.y > (1.0 - lineThickness))
                {
                    col.rgb *= 0.6; //darken the edges so you can see the grid
                }

                return col;
            }
            ENDCG
        }
    }
}
