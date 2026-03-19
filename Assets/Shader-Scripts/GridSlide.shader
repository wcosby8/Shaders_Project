Shader "Custom/GridSlide"
{
    Properties
    {
        // The main texture to display in the sliding grid
        _MainTex ("Texture", 2D) = "white" {}
        
        // How many grid cells across and down (e.g. 4 = 4x4 = 16 tiles)
        _GridSize ("Grid Size", Float) = 4.0
        
        // How fast the grid cycles through its 4 phases (seconds per phase)
        _PhaseSpeed ("Phase Speed", Float) = 0.7
        
        // How far each tile slides during its phase (in UV space, 0-1)
        // 1.0 = slides exactly one full tile width before snapping back
        _SlideAmount ("Slide Amount", Float) = 1.0
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
                float4 vertex : POSITION;   // Vertex position in object space
                float2 uv : TEXCOORD0;      // UV coordinates for this vertex
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;       // UV interpolated to this pixel
                float4 vertex : SV_POSITION; // Final screen position
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _GridSize;
            float _PhaseSpeed;
            float _SlideAmount;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // -------------------------------------------------------
            // FRAGMENT SHADER - GRID SLIDE
            //
            // KEY CONCEPT - Every tile moves in every phase:
            // Each tile has a per-tile direction sign based on its grid position.
            // Horizontal direction alternates by ROW (even rows right, odd left).
            // Vertical direction alternates by COLUMN (even cols up, odd down).
            //
            // KEY CONCEPT - Cumulative displacement across phases:
            // Rather than each phase independently starting from rest, we track
            // the tile's TOTAL 2D offset as it accumulates and then returns.
            // This ensures smooth, continuous motion with no pops at phase seams.
            //
            // Phase 0: X slides out  (0 -> displaced),  Y stays 0
            // Phase 1: X held,                           Y slides out (0 -> displaced)
            // Phase 2: X returns     (displaced -> 0),   Y held
            // Phase 3: X stays 0,                        Y returns (displaced -> 0)
            //
            // At the end of phase 3 both offsets reach 0, restoring every tile
            // to its correct position and completing the loop seamlessly.
            // -------------------------------------------------------
            fixed4 frag (v2f i) : SV_Target
            {
                // --- DETERMINE WHICH GRID CELL THIS PIXEL BELONGS TO ---
                // Multiply UV by grid size to "tile" the space (0-1 becomes 0-GridSize)
                float2 scaledUV = i.uv * _GridSize;

                // floor() gives the integer cell index: (0,0) to (GridSize-1, GridSize-1)
                float2 cellCoord = floor(scaledUV);

                // frac() gives the local position within the tile (0 to 1)
                float2 localUV = frac(scaledUV);

                // --- PHASE AND SLIDE PROGRESS ---
                float phaseTime = _Time.y * _PhaseSpeed;
                int phase = (int)fmod(floor(phaseTime), 4.0);

                // slideT ramps smoothly 0->1 over each phase
                float slideT = frac(phaseTime);

                // --- PER-TILE DIRECTION SIGNS ---
                // Horizontal: alternates by row  — even rows go right (+1), odd go left (-1)
                float dirX = (fmod(cellCoord.y, 2.0) < 1.0) ? 1.0 : -1.0;

                // Vertical: alternates by column — even cols go up (+1), odd go down (-1)
                float dirY = (fmod(cellCoord.x, 2.0) < 1.0) ? 1.0 : -1.0;

                // --- CUMULATIVE DISPLACEMENT ---
                // Each phase moves one axis while the other is either held or zeroed,
                // so the total offset returns to (0,0) at the end of the 4-phase cycle.
                float2 offset = float2(0.0, 0.0);

                if (phase == 0)
                {
                    // X slides from 0 to full displacement; Y not yet engaged
                    offset.x = dirX * slideT * _SlideAmount;
                    offset.y = 0.0;
                }
                else if (phase == 1)
                {
                    // X held at its full displaced value; Y now slides out
                    offset.x = dirX * _SlideAmount;
                    offset.y = dirY * slideT * _SlideAmount;
                }
                else if (phase == 2)
                {
                    // X returns from full displacement back to 0; Y held
                    offset.x = dirX * (1.0 - slideT) * _SlideAmount;
                    offset.y = dirY * _SlideAmount;
                }
                else // phase == 3
                {
                    // X already at 0; Y returns to 0 — tiles reassemble
                    offset.x = 0.0;
                    offset.y = dirY * (1.0 - slideT) * _SlideAmount;
                }

                // --- BUILD FINAL SAMPLE UV ---
                // Add cell origin + local position + slide offset, then
                // divide by GridSize to normalize back to 0-1 UV space.
                // frac() wraps tiles that slide beyond the texture boundary.
                float2 finalUV = frac((cellCoord + localUV + offset) / _GridSize);

                // Sample the texture at the computed UV position
                fixed4 col = tex2D(_MainTex, finalUV);

                // --- GRID LINES ---
                // Darken pixels near tile edges to show the sliding grid structure
                float lineThickness = 0.03;
                if (localUV.x < lineThickness || localUV.x > (1.0 - lineThickness) ||
                    localUV.y < lineThickness || localUV.y > (1.0 - lineThickness))
                {
                    col.rgb *= 0.6;
                }

                return col;
            }
            ENDCG
        }
    }
}
