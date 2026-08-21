struct VertexInput {
    float3 position : TEXCOORD0;
    float3 shape : TEXCOORD1;
    float2 local : TEXCOORD2;
    float4 color : TEXCOORD3;
    float2 modelX : TEXCOORD4;
    float2 modelY : TEXCOORD5;
    float2 modelTranslation : TEXCOORD6;
    float modelDepth : TEXCOORD7;
    float4 materialColor : TEXCOORD8;
};

cbuffer ViewUniforms : register(b0, space1) {
    float4x4 viewProjection;
};

struct VertexOutput {
    float4 color : COLOR0;
    float3 shape : TEXCOORD0;
    float2 local : TEXCOORD1;
    float mode : TEXCOORD2;
    float4 position : SV_Position;
};

VertexOutput vertex_main(VertexInput input) {
    const float2 worldPosition = input.modelX * input.position.x +
        input.modelY * input.position.y + input.modelTranslation;
    const float4 world = float4(worldPosition, input.modelDepth, 1.0);
    VertexOutput output;
    output.position = mul(viewProjection, world);
    output.color = input.color * input.materialColor;
    output.shape = input.shape;
    output.local = input.local;
    output.mode = input.position.z;
    return output;
}

float rounded_box_distance(float2 coordinate, float2 halfSize, float radius) {
    const float2 q = abs(coordinate) - (halfSize - radius);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float line_distance(float2 coordinate, float2 shape, float cap) {
    if (cap > -2.5) {
        const float2 q = abs(coordinate) - shape;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    }
    if (cap > -3.5) {
        return length(float2(max(abs(coordinate.x) - shape.x, 0.0), coordinate.y)) - shape.y;
    }
    const float2 square = float2(shape.x + shape.y, shape.y);
    const float2 q = abs(coordinate) - square;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    if (input.mode < 0.0) { return input.color; }
    float distance;
    if (input.shape.z < -1.5) {
        distance = line_distance(input.local, input.shape.xy, input.shape.z);
    } else if (input.shape.z < -0.5) {
        distance = length(input.local) - input.shape.x;
    } else {
        distance = rounded_box_distance(input.local, input.shape.xy, input.shape.z);
    }
    float edge = distance;
    if (input.mode > 0.0 && input.shape.z >= -1.5) {
        edge = abs(distance) - input.mode * 0.5;
    }
    const float antialias = max(fwidth(edge), 0.0001);
    const float coverage = saturate(0.5 - edge / antialias);
    return float4(input.color.rgb, input.color.a * coverage);
}
