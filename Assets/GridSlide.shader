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
            // KEY CONCEPT - Tiling by Quadrants:
            // We divide the UV space into a grid of tiles using floor().
            // Each tile gets an integer "cell coordinate" (cellX, cellY).
            // Within each tile, we have a "local UV" from 0 to 1.
            //
            // KEY CONCEPT - Step Functions:
            // fmod(floor(_Time.y * _PhaseSpeed), 4) gives us a value 
            // that steps through 0, 1, 2, 3, 0, 1, 2, 3 ... over time.
            // This is our "phase". Each phase slides a different set of tiles.
            //
            // KEY CONCEPT - Four Phases:
            // Phase 0: Even columns slide LEFT  (negative X offset)
            // Phase 1: Even rows   slide DOWN   (positive Y offset)
            // Phase 2: Odd columns slide RIGHT  (positive X offset)
            // Phase 3: Odd rows    slide UP     (negative Y offset)
            // Together these create a "coming together" effect where tiles
            // converge into a complete image at the end of phase 3.
            //
            // The slide amount within each phase is a smooth 0->1 ramp
            // using frac() of the time - so each phase animates smoothly.
            // -------------------------------------------------------
            fixed4 frag (v2f i) : SV_Target
            {
                // --- DETERMINE WHICH GRID CELL THIS PIXEL BELONGS TO ---
                // Multiply UV by grid size to "tile" the space
                // e.g. with GridSize=4: UV 0-1 becomes 0-4
                float2 scaledUV = i.uv * _GridSize;
                
                // floor() rounds down to get the integer cell index
                // cellCoord tells us which tile we're in: (0,0) to (GridSize-1, GridSize-1)
                float2 cellCoord = floor(scaledUV);
                
                // frac() gives us the position WITHIN the current tile (0 to 1)
                // This is our local UV inside just this one tile
                float2 localUV = frac(scaledUV);

                // --- DETERMINE CURRENT PHASE (0, 1, 2, or 3) ---
                // _Time.y * _PhaseSpeed converts time to phase-space
                // floor() rounds it to integer steps
                // fmod(x, 4) wraps it to 0-3 (HLSL's modulo for floats)
                float phaseTime = _Time.y * _PhaseSpeed;
                int phase = (int)fmod(floor(phaseTime), 4.0);
                
                // The smooth progress within the CURRENT phase (0.0 to 1.0)
                // frac() extracts just the fractional seconds-within-phase
                // This ramps smoothly from 0 to 1 over each phase duration
                float phaseProgress = frac(phaseTime);

                // --- CALCULATE THE SLIDE OFFSET FOR THIS TILE ---
                // We'll accumulate a UV offset based on phase and cell position
                float2 offset = float2(0.0, 0.0);

                // Phase 0: Even-column tiles slide left (negative X direction)
                // fmod(cellCoord.x, 2) == 0 checks if this column is even (0, 2, 4...)
                if (phase == 0)
                {
                    // Even columns: slide left by phaseProgress (0 to _SlideAmount)
                    if (fmod(cellCoord.x, 2.0) < 1.0)
                        offset.x = -phaseProgress * _SlideAmount;
                    // Odd columns don't move in this phase
                }
                // Phase 1: Even-row tiles slide downward (positive Y direction in UV)
                else if (phase == 1)
                {
                    // Even rows: slide down
                    if (fmod(cellCoord.y, 2.0) < 1.0)
                        offset.y = phaseProgress * _SlideAmount;
                    // Odd rows don't move
                }
                // Phase 2: Odd-column tiles slide right (positive X direction)
                else if (phase == 2)
                {
                    // Odd columns: slide right
                    if (fmod(cellCoord.x, 2.0) >= 1.0)
                        offset.x = phaseProgress * _SlideAmount;
                    // Even columns don't move
                }
                // Phase 3: Odd-row tiles slide upward (negative Y direction in UV)
                else // phase == 3
                {
                    // Odd rows: slide up - this is the "coming together" phase
                    if (fmod(cellCoord.y, 2.0) >= 1.0)
                        offset.y = -phaseProgress * _SlideAmount;
                    // Even rows don't move
                }

                // --- BUILD FINAL SAMPLE UV ---
                // Convert the cell + localUV back to a 0-1 texture UV.
                // We add the cell coordinate (to position within the grid),
                // add the local UV (position within the tile),
                // add the slide offset, then divide by GridSize to normalize back to 0-1.
                // frac() at the end makes it wrap seamlessly if a tile slides off-screen.
                float2 finalUV = frac((cellCoord + localUV + offset) / _GridSize);

                // Sample the texture at our computed UV position
                fixed4 col = tex2D(_MainTex, finalUV);

                // --- OPTIONAL: DRAW THIN GRID LINES FOR VISUAL CLARITY ---
                // lineThickness controls how thick the grid borders appear
                // Values like 0.03 give a thin visible line between tiles
                float lineThickness = 0.03;
                
                // If the local UV is within `lineThickness` of an edge, darken the pixel
                // This creates visible grid seams so you can see the tile boundaries
                if (localUV.x < lineThickness || localUV.x > (1.0 - lineThickness) ||
                    localUV.y < lineThickness || localUV.y > (1.0 - lineThickness))
                {
                    // Darken edge pixels by 40% to show the grid structure
                    col.rgb *= 0.6;
                }

                return col;
            }
            ENDCG
        }
    }
}
