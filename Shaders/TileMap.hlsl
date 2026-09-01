struct VertexInput {
    float2 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float2 translation : TEXCOORD2;
    float4 uvRegion : TEXCOORD3;
};

cbuffer DrawUniforms : register(b0, space1) {
    float4x4 model;
    float4x4 viewProjection;
    float2 tileSize;
    float depth;
    float padding;
    float4 tint;
};

Texture2D<float4> atlasTexture : register(t0, space2);
SamplerState atlasSampler : register(s0, space2);

struct VertexOutput {
    float2 uv : TEXCOORD0;
    float4 color : COLOR0;
    float4 position : SV_Position;
};

VertexOutput vertex_main(VertexInput input) {
    const float2 offset = float2(
        (input.position.x - 0.5) * tileSize.x,
        -(input.position.y - 0.5) * tileSize.y
    );
    const float4 world = mul(model, float4(input.translation + offset, depth, 1.0));
    VertexOutput output;
    output.position = mul(viewProjection, world);
    output.uv = input.uvRegion.xy + input.uv * input.uvRegion.zw;
    output.color = tint;
    return output;
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    return atlasTexture.Sample(atlasSampler, input.uv) * input.color;
}
