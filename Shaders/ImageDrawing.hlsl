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

cbuffer ImageUniforms : register(b0, space3) {
    float4 mappingFrame;
    float4 destinationFrame;
    float4 sourceRegion;
    float4 tileCoordinates;
    float4 imageSettings;
};

Texture2D<float4> imageTexture : register(t0, space2);
SamplerState imageSampler : register(s0, space2);

struct VertexOutput {
    float4 color : COLOR0;
    float3 shape : TEXCOORD0;
    float2 local : TEXCOORD1;
    float mode : TEXCOORD2;
    float2 canvasPosition : TEXCOORD3;
    float4 position : SV_Position;
};

VertexOutput vertex_main(VertexInput input) {
    const float2 worldPosition = input.modelX * input.position.x +
        input.modelY * input.position.y + input.modelTranslation;
    VertexOutput output;
    output.position = mul(viewProjection, float4(worldPosition, input.modelDepth, 1.0));
    output.color = input.color * input.materialColor;
    output.shape = input.shape;
    output.local = input.local;
    output.mode = input.position.z;
    output.canvasPosition = input.position.xy;
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

int wrapped(int value, int size) {
    const int result = value % size;
    return result < 0 ? result + size : result;
}

float4 texel(int2 local) {
    uint width;
    uint height;
    imageTexture.GetDimensions(width, height);
    const float2 coordinate = float2(int2(sourceRegion.xy) + local) + 0.5;
    return imageTexture.SampleLevel(
        imageSampler,
        coordinate / float2(width, height),
        0.0
    );
}

float4 smooth_fit(float2 normalized) {
    const float2 coordinate = -0.5 + normalized * sourceRegion.zw;
    const int2 first = int2(floor(coordinate));
    const float2 amount = coordinate - first;
    const int2 maximum = int2(sourceRegion.zw) - 1;
    const int2 a = clamp(first, int2(0, 0), maximum);
    const int2 b = clamp(first + 1, int2(0, 0), maximum);
    return lerp(
        lerp(texel(int2(a.x, a.y)), texel(int2(b.x, a.y)), amount.x),
        lerp(texel(int2(a.x, b.y)), texel(int2(b.x, b.y)), amount.x),
        amount.y
    );
}

float4 smooth_tile(float2 coordinate) {
    const int2 size = int2(sourceRegion.zw);
    const float2 repeated = coordinate - floor(coordinate / sourceRegion.zw) * sourceRegion.zw - 0.5;
    const int2 first = int2(floor(repeated));
    const float2 amount = repeated - first;
    const int2 a = int2(wrapped(first.x, size.x), wrapped(first.y, size.y));
    const int2 b = int2(wrapped(first.x + 1, size.x), wrapped(first.y + 1, size.y));
    return lerp(
        lerp(texel(int2(a.x, a.y)), texel(int2(b.x, a.y)), amount.x),
        lerp(texel(int2(a.x, b.y)), texel(int2(b.x, b.y)), amount.x),
        amount.y
    );
}

float4 mapped_color(float2 canvasPoint) {
    const bool tile = imageSettings.z > 0.5;
    const bool pixelated = imageSettings.w > 0.5;
    if (tile) {
        const float2 coordinate = (canvasPoint - tileCoordinates.xy) / tileCoordinates.zw;
        if (!pixelated) { return smooth_tile(coordinate); }
        const int2 size = int2(sourceRegion.zw);
        const int2 local = int2(floor(coordinate));
        return texel(int2(wrapped(local.x, size.x), wrapped(local.y, size.y)));
    }
    if (any(canvasPoint < mappingFrame.xy) || any(canvasPoint >= mappingFrame.xy + mappingFrame.zw)) {
        discard;
    }
    if (any(canvasPoint < destinationFrame.xy) || any(canvasPoint >= destinationFrame.xy + destinationFrame.zw)) {
        discard;
    }
    const float2 normalized = (canvasPoint - destinationFrame.xy) / destinationFrame.zw;
    if (!pixelated) { return smooth_fit(normalized); }
    const int2 local = min(
        int2(floor(normalized * sourceRegion.zw)),
        int2(sourceRegion.zw) - 1
    );
    return texel(local);
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    float coverage = 1.0;
    if (input.mode >= 0.0) {
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
        coverage = saturate(0.5 - edge / max(fwidth(edge), 0.0001));
    }
    const float4 sampled = mapped_color(input.canvasPosition) * input.color;
    return float4(sampled.rgb, sampled.a * coverage);
}
