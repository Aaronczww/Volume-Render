// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _Centre("_Centre",Vector) = (0,0,0)
        _Radius("_Radius",float) = 1
        STEPS("STEPS",float) = 100
        STEP_SIZE("STEP_SIZE",float) = 0.02
        MIN_DISTANCE("MIN_DISTANCE",float) = 0.002
        _Color("_Color",Color) = (1,1,1,1)
        _S("S",Vector) = (0,0,0)
        _C("C",Vector) = (0,0,0)
        _alpha("_alpha",Range(0,1)) = 0.5
        _K("K",float) = 32
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 wPos:TEXCOORD1;
            };

            float STEP_SIZE;
            float STEPS;
            float _Radius;
            float3 _Centre;
            float MIN_DISTANCE;
            float4 _Color;

            float3 _S;
            float3 _C;
            float _alpha;
            float _K;

            float2 hash22(float2 p) {
				p = float2(dot(p,float2(127.1,311.7)),dot(p,float2(269.5,183.3)));
				return -1.0 + 2.0*frac(sin(p)*43758.5453123);
			}


            float perlin_noise(float2 p) {				
				float2 pi = floor(p);
				float2 pf = p - pi;
				float2 w = pf * pf*(3.0 - 2.0*pf);
				return lerp(lerp(dot(hash22(pi + float2(0.0, 0.0)), pf - float2(0.0, 0.0)),
					dot(hash22(pi + float2(1.0, 0.0)), pf - float2(1.0, 0.0)), w.x),
					lerp(dot(hash22(pi + float2(0.0, 1.0)), pf - float2(0.0, 1.0)),
						dot(hash22(pi + float2(1.0, 1.0)), pf - float2(1.0, 1.0)), w.x), w.y);
			}

            float sdf_sphere(float3 p)
            {
                return (distance(p,_Centre-float3(0,0,0)) - _Radius);
            }

            

            float sdf_box (float3 p, float3 c, float3 s)
            {
                float x = max
                (   p.x - c.x - float3(s.x / 2., 0, 0),
                    c.x - p.x - float3(s.x / 2., 0, 0)
                );
            
                float y = max
                (   p.y - c.y - float3(s.y / 2., 0, 0),
                    c.y - p.y - float3(s.y / 2., 0, 0)
                );
                
                float z = max
                (   p.z - c.z - float3(s.z / 2., 0, 0),
                    c.z - p.z - float3(s.z / 2., 0, 0)
                );
            
                float d = x;
                d = max(d,y);
                d = max(d,z);
                return d;
            }

            float sdf_Blend(float d1,float d2,float alpha)
            {
                return alpha * d1 + (1 - alpha) * d2;
            }

            float sdf_smin(float a, float b, float k = 32)
            {
                float res = exp(-k*a) + exp(-k*b);
                return -log(max(0.0001,res)) / k;
            }

            float differenceSDF(float distA, float distB) {
                return max(distA, -distB);
            }

            float3 normal (float3 p)
            {
                const float eps = 0.01;

                return normalize(p);
                
                return normalize
                ( float3
                ( length(p + float3(eps, 0, 0) ) - length(p - float3(eps, 0, 0)),
                length(p + float3(0, eps, 0) ) - length(p - float3(0, eps, 0)),
                length(p + float3(0, 0, eps) ) - length(p - float3(0, 0, eps))
                )
                );
            }

            fixed4 simpleLambert (fixed3 normal,float3 viewDirection) {
                fixed3 lightDir = _WorldSpaceLightPos0.xyz; // Light direction
                fixed3 lightCol = _LightColor0.rgb; // Light color
                
                fixed NdotL = max(dot(normal, lightDir),0);
                fixed4 c;
                
                // Specular
                fixed3 h = (lightDir - viewDirection) / 2.;
                fixed s = pow( dot(normal, h), 64);
                c.rgb = _Color * lightCol * NdotL + s;

                // c.rgb = float3(1,0,0);
                c.a = 1;
                return c;
            }

            fixed4 renderSurface(float3 p,float3 viewDir)
            {
                float3 n = normal(p);
                return simpleLambert(n,viewDir);
            }


            fixed4 raymarch (float3 position, float3 direction)
            {
                for (int i = 0; i < STEPS; i++)
                {
                    float boxdistance = sdf_box(position,_C,_S);
                    float spheredistance = sdf_sphere(position);
                    float distance = max(boxdistance,spheredistance);
                    distance =  sdf_Blend(boxdistance,spheredistance,_alpha);
                    distance = sdf_smin(boxdistance,spheredistance,_K);
                    if(distance < MIN_DISTANCE)
                    {
                        return renderSurface(position,direction);
                    }
                    position += direction * distance;
                }
            
                return fixed4(1,1,1,0); // White
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 worlPos = i.wPos;
                float3 viewDir = normalize(worlPos - _WorldSpaceCameraPos);
                float4 col = raymarch(worlPos,viewDir);
                return col;
            }
            ENDCG
        }
    }
}
