#include "bindless.hlsli"

struct PushConsts {
    uint2 resolution;
    float2 texel_size;
    uint input_image_index;
    uint output_image_index;
};

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 0);
RWTexture2D<float4> g_rw_textures[65536] : REGISTER_UAV(1, 0, 0);

PUSH_CONSTS(PushConsts, g_push_consts);

// Uchimura 2017, "HDR theory and practice"
// Math: https://www.desmos.com/calculator/gslcdxvipg
// Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
float3 uchimura(float3 x, float P, float a, float m, float l, float c, float b)
{
	float l0 = ((P - m) * l) / a;
	float L0 = m - m / a;
	float L1 = m + (1.0f - m) / a;
	float S0 = m + l0;
	float S1 = m + a * l0;
	float C2 = (a * P) / (P - S1);
	float CP = -C2 / P;
	
	float3 w0 = 1.0f - smoothstep(0.0f, m, x);
	float3 w2 = step(m + l0, x);
	float3 w1 = 1.0f - w0 - w2;
	
	float3 T = m * pow(x / m, c) + b;
	float3 S = P - (P - S1) * exp(CP * (x - S0));
	float3 L = m + a * (x - m);
	
	return T * w0 + L * w1 + S * w2;
}

float3 uchimura(float3 x)
{
	const float P = 1.0;  // max display brightness
	const float a = 1.0;  // contrast
	const float m = 0.22; // linear section start
	const float l = 0.4;  // linear section length
	const float c = 1.33; // black
	const float b = 0.0;  // pedestal
	
	return uchimura(x, P, a, m, l, c, b);
}


[numthreads(8, 8, 1)]
void main(uint3 thread_id: SV_DispatchThreadID) {

    float3 color = g_textures[g_push_consts.input_image_index].Load(int3(thread_id.xy, 0)).rgb;
    color = uchimura(color);

    g_rw_textures[g_push_consts.output_image_index][thread_id.xy] = float4(color, 1.f);
}