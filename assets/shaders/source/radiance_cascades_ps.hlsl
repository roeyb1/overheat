#include "bindless.hlsli"

struct PSInput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
};

struct PSOutput {
    float4 color: SV_Target0;
};

struct DrawConstants {
    float2 cascade_extent;
    float2 render_extent;

    uint df_texture;
    uint lightmap_texture;
    uint previous_rt;

    float cascade_index;
    float cascade_count;
    float cascade_linear;
    float cascade_interval;
};

Texture2D<float4> g_textures[65536] : REGISTER_SRV(0, 0, 0);

SamplerState g_linear_clamp_sampler : REGISTER_SAMPLER(0, 0, 1);

PUSH_CONSTS(DrawConstants, g_draw_consts);

#define PI 3.14159265
#define TAU (2.0 * PI)
#define EPSILON 0.001
#define SQRT_2 1.41

struct ProbeInfo {
    float angular;
    float2 linear_spacing;
    float2 size;
    float2 probe;
    float index;
    float offset;
    float range;
    float scale;
};

ProbeInfo cascade_texel_info(float2 coord, float2 pixel_texcoord) {
    ProbeInfo result;
    float angular = pow(2., float(g_draw_consts.cascade_index));

    result.angular = angular * angular;
    float linear_spacing = g_draw_consts.cascade_linear * pow(2., float(g_draw_consts.cascade_index));
    result.linear_spacing = float2(linear_spacing.xx);
    result.size = g_draw_consts.cascade_extent / angular;
    result.probe = fmod(floor(coord), result.size);

    float2 ray_pos = floor(pixel_texcoord * angular);

    result.index = ray_pos.x + (angular * ray_pos.y);
    result.offset = (float(g_draw_consts.cascade_interval) * (1. - pow(4., float(g_draw_consts.cascade_index)))) / (1. - 4.);
    result.range = float(g_draw_consts.cascade_interval) * pow(4, float(g_draw_consts.cascade_index));
    result.range += length(float2(g_draw_consts.cascade_linear.xx * pow(2., g_draw_consts.cascade_index + 1.)));
    result.scale = length(g_draw_consts.render_extent);

    return result;
}

float4 raymarch(float2 pos, float theta, ProbeInfo info) {
    float2 texel = 1. / g_draw_consts.render_extent;
    float2 delta = float2(cos(theta), -sin(theta));
    float2 ray = (pos + (delta * info.offset)) * texel;

    for (float i = 0., df = 0., rd = 0.; i < info.range; ++i) {
        df = g_textures[g_draw_consts.df_texture].SampleLevel(g_linear_clamp_sampler, ray, 0).r;
        rd += df * info.scale;
        ray += (delta * df * info.scale * texel);

        if (rd >= info.range || any(floor(ray) != float2(0..xx))) break;
        if (df <= EPSILON && rd <= EPSILON && g_draw_consts.cascade_index != 0.) return float4(0., 0., 0., 0.);
        if (df <= EPSILON) return float4(g_textures[g_draw_consts.lightmap_texture].SampleLevel(g_linear_clamp_sampler, ray, 0).rgb, 0.);
    }

    return float4(0., 0., 0., 1.);
}

float4 merge(float4 rinfo, float index, ProbeInfo pinfo) {
    if (rinfo.a == 0. || g_draw_consts.cascade_index >= g_draw_consts.cascade_count - 1) {
        return float4(rinfo.rgb, 1. - rinfo.a);
    }

    float angularN1 = pow(2., g_draw_consts.cascade_index + 1);
    float2 sizeN1 = pinfo.size * 0.5;
    float2 probeN1 = float2(fmod(index, angularN1), floor(index / angularN1)) * sizeN1;
    float2 interpUVN1 = (pinfo.probe * 0.5) + 0.25;
    float2 clampedUVN1 = max(float2(1..xx), min(interpUVN1, sizeN1 - 1.));
    float2 probeUVN1 = probeN1 + clampedUVN1;
    float4 interpolated = g_textures[g_draw_consts.previous_rt].SampleLevel(g_linear_clamp_sampler, probeUVN1 * (1. / float2(g_draw_consts.cascade_extent)), 0);
    return rinfo + interpolated;
}


PSOutput main(PSInput input) {
    PSOutput output;

    ProbeInfo pinfo = cascade_texel_info(floor(input.tex_coord * g_draw_consts.cascade_extent), input.tex_coord);
    float2 origin = (pinfo.probe + 0.5) * pinfo.linear_spacing;
    float preavg_index = pinfo.index * 4.;
    float theta_scalar = TAU / (pinfo.angular * 4.);

    output.color = float4(0., 0., 0., 0.);

    for (float i = 0.; i < 4.; ++ i) {
        float index = preavg_index + i;
        float theta = (index + 0.5) * theta_scalar;

        float4 rinfo = raymarch(origin, theta, pinfo);
        output.color += merge(rinfo, index, pinfo) * 0.25;
    }

    if (g_draw_consts.cascade_index == 0) {
        output.color.a = 1.;
    }

    return output;
}
