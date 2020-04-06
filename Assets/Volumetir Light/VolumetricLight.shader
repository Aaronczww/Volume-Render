Shader "Unlit/VolumetricLight"
{
    Properties
    {
        _TransmittanceExtinction("TransmittanceExtinction",Vector) = (1,1,1)
          _AbsorptionRatio ("Absorption Ratio", Range(0, 1)) = 0.5
        _HGFactor("HG Phase Factor",Range(-1,1)) = 1
        _Steps("_Steps",float) = 256
        _IncomingLoss("_IncomingLoss",float) = 1
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


            float3 _TransmittanceExtinction;
            float _HGFactor;
            float _Steps;
            float _IncomingLoss;
            float _AbsorptionRatio;

            #define PI 3.14159265

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float3 extinctionAt(float3 pos)
            {
                return 1 * _TransmittanceExtinction;
            }

            float phaseHG(float3 lightDir, float3 viewDir)
            {
                float g = _HGFactor;
                return (1 - g * g) / (4 * PI * pow(1 + g * g - 2 * g * dot(viewDir, lightDir), 1.5)); 
            }

            float3 lightAt(float3 pos, out float3 lightDir)
            {
                lightDir = normalize(_WorldSpaceLightPos0.xyz - pos);
                float lightDistance = distance(_WorldSpaceLightPos0.xyz, pos);
                float3 transmittance = lerp(1, exp(-lightDistance * _TransmittanceExtinction), _IncomingLoss);
                float3 inScatter = _TransmittanceExtinction * (1 - _AbsorptionRatio);

                float3 lightColor = float3(1,1,1);
                // lightColor *= step(_LightCosHalfAngle, dot(lightDir, _LightDirection));
                // lightColor *= shadowAt(pos);
                lightColor *= inScatter;
                lightColor *= transmittance;
                return lightColor;
            }

            float3 scattering(float3 ray, float near, float far, out float3 transmittance)
            {
                transmittance = 1;
                float3 totalLight = 0;
                float stepSize = (far - near) / _Steps;
                for(int i = 1; i <_Steps ; i++)
                {
                    float3 pos = _WorldSpaceCameraPos + ray * (near + stepSize * i);
                    float3 extinction = extinctionAt(pos);
                    transmittance = transmittance * exp(-stepSize * extinction);
                    float3 lightDir;
                    totalLight += transmittance * lightAt(pos,lightDir) * stepSize * phaseHG(lightDir,-ray);
                }
                return totalLight;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = float4(1,1,1,1);
                return col;
            }
            ENDCG
        }
    }
}
