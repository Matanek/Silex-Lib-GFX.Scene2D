struct VertexInput {
    float2 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float2 modelX : TEXCOORD2;
    float2 modelY : TEXCOORD3;
    float2 modelTranslation : TEXCOORD4;
    float modelDepth : TEXCOORD5;
    float4 uvRegion : TEXCOORD6;
    float4 color : TEXCOORD7;
};

cbuffer ViewUniforms : register(b0, space1) {
    float4x4 viewProjection;
    float2 canvasX;
    float2 canvasY;
    float2 canvasTranslation;
    float2 uniformPadding;
    float4 clipBounds;
};

Texture2D<float> coverageTexture : register(t0, space2);
SamplerState coverageSampler : register(s0, space2);

struct VertexOutput {
    float2 uv : TEXCOORD0;
    float2 localPosition : TEXCOORD1;
    float4 color : COLOR0;
    float4 position : SV_Position;
};

VertexOutput vertex_main(VertexInput input) {
    const float2 localPosition = input.modelX * input.position.x +
        input.modelY * input.position.y + input.modelTranslation;
    const float2 worldPosition = canvasX * localPosition.x +
        canvasY * localPosition.y + canvasTranslation;
    VertexOutput output;
    output.position = mul(viewProjection, float4(worldPosition, input.modelDepth, 1.0));
    output.uv = input.uvRegion.xy + input.uv * input.uvRegion.zw;
    output.localPosition = localPosition;
    output.color = input.color;
    return output;
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    if (input.localPosition.x < clipBounds.x || input.localPosition.y < clipBounds.y ||
        input.localPosition.x >= clipBounds.z || input.localPosition.y >= clipBounds.w) {
        discard;
    }
    const float coverage = coverageTexture.Sample(coverageSampler, input.uv);
    return float4(input.color.rgb, input.color.a * coverage);
}
