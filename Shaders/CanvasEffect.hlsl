cbuffer EffectUniforms : register(b0, space3) {
    float4 textureSize;
    float4 directionRadiusMode;
    float4 offsetOpacity;
    float4 shadowColor;
};

Texture2D<float4> sourceTexture : register(t0, space2);
SamplerState sourceSampler : register(s0, space2);
Texture2D<float4> auxiliaryTexture : register(t1, space2);
SamplerState auxiliarySampler : register(s1, space2);

struct VertexOutput {
    float2 uv : TEXCOORD0;
    float4 position : SV_Position;
};

VertexOutput vertex_main(uint id : SV_VertexID) {
    const float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };
    VertexOutput output;
    output.position = float4(positions[id], 0.0, 1.0);
    output.uv = float2(
        positions[id].x * 0.5 + 0.5,
        0.5 - positions[id].y * 0.5
    );
    return output;
}

float gaussian_weight(float distance, float sigma) {
    return exp(-(distance * distance) / (2.0 * sigma * sigma));
}

float4 source_at(int2 coordinate) {
    if (any(coordinate < 0) || any(coordinate >= int2(textureSize.zw))) {
        return 0.0;
    }
    return sourceTexture.SampleLevel(
        sourceSampler,
        ((float2)coordinate + 0.5) * textureSize.xy,
        0.0
    );
}

float auxiliary_alpha_at(int2 coordinate) {
    if (any(coordinate < 0) || any(coordinate >= int2(textureSize.zw))) {
        return 0.0;
    }
    return auxiliaryTexture.SampleLevel(
        auxiliarySampler,
        ((float2)coordinate + 0.5) * textureSize.xy,
        0.0
    ).a;
}

float4 blurred(int2 coordinate) {
    const float radius = directionRadiusMode.z;
    if (radius <= 0.0) { return source_at(coordinate); }
    const int support = max(1, (int)ceil(radius));
    const float sigma = max(radius / 3.0, 1.0 / 3.0);
    const int2 step = int2(directionRadiusMode.xy);
    float4 result = 0.0;
    float total = 0.0;
    for (int offset = -support; offset <= support; ++offset) {
        const float weight = gaussian_weight((float)offset, sigma);
        result += source_at(coordinate + step * offset) * weight;
        total += weight;
    }
    return result / total;
}

float shadow_alpha(float2 coordinate) {
    const int2 first = int2(floor(coordinate));
    const float2 amount = coordinate - first;
    const float top = lerp(
        auxiliary_alpha_at(first),
        auxiliary_alpha_at(first + int2(1, 0)),
        amount.x
    );
    const float bottom = lerp(
        auxiliary_alpha_at(first + int2(0, 1)),
        auxiliary_alpha_at(first + int2(1, 1)),
        amount.x
    );
    return lerp(top, bottom, amount.y);
}

float4 shadowed(int2 coordinate) {
    const float4 source = source_at(coordinate);
    const float mask = shadow_alpha((float2)coordinate - offsetOpacity.xy);
    const float shadowAlpha = mask * shadowColor.a;
    const float4 shadow = float4(shadowColor.rgb * shadowAlpha, shadowAlpha);
    return source + shadow * (1.0 - source.a);
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    const int2 coordinate = int2(input.position.xy);
    if (directionRadiusMode.w < 0.5) {
        return source_at(coordinate) * offsetOpacity.z;
    }
    if (directionRadiusMode.w < 1.5) { return blurred(coordinate); }
    return shadowed(coordinate);
}
