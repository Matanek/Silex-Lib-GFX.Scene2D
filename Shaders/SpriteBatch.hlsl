struct VertexInput {
    float2 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float2 modelX : TEXCOORD2;
    float2 modelY : TEXCOORD3;
    float4 translationDepth : TEXCOORD4;
    float4 sizePivot : TEXCOORD5;
    float4 tint : TEXCOORD6;
    float4 uvRegion : TEXCOORD7;
};

cbuffer DrawUniforms : register(b0, space1) {
    float4x4 viewProjection;
};

Texture2D<float4> spriteTexture : register(t0, space2);
SamplerState spriteSampler : register(s0, space2);

struct VertexOutput {
    float2 uv : TEXCOORD0;
    nointerpolation float4 uvRegion : TEXCOORD1;
    float4 color : COLOR0;
    float4 position : SV_Position;
};

VertexOutput vertex_main(VertexInput input) {
    const float2 local = (input.position - input.sizePivot.zw) * input.sizePivot.xy;
    const float2 world = input.translationDepth.xy +
        input.modelX * local.x + input.modelY * local.y;
    VertexOutput output;
    output.position = mul(
        viewProjection,
        float4(world, input.translationDepth.z, 1.0)
    );
    output.uv = input.uvRegion.xy + input.uv * input.uvRegion.zw;
    output.uvRegion = input.uvRegion;
    output.color = input.tint;
    return output;
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    // MSAA can shade a pixel whose center lies outside the covered triangle.
    // Clamp the lookup, not the UV mapping, to keep every atlas texel its size.
    uint width;
    uint height;
    spriteTexture.GetDimensions(width, height);
    const float2 halfTexel = 0.5 / float2(width, height);
    const float2 lower = input.uvRegion.xy + halfTexel;
    const float2 upper = input.uvRegion.xy + input.uvRegion.zw - halfTexel;
    const float2 uv = clamp(input.uv, lower, upper);
    return spriteTexture.Sample(spriteSampler, uv) * input.color;
}
