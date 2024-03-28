struct VSOutput {
    float4 position: SV_Position;
    float2 tex_coord: TEXCOORD;
};

VSOutput main(uint vertex_id: SV_VertexID) {
    VSOutput output;

    float x = -1.f + float((vertex_id & 2) << 1);
    float y = -1.f + float((vertex_id & 1) << 2);

    output.position = float4(x, y, 0.f, 1.f);
    output.tex_coord = output.position.xy * float2(0.5f, -0.5f) + 0.5f;

    return output;
}