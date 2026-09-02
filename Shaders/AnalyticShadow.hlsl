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
    float2 center : TEXCOORD9;
    float2 axis : TEXCOORD10;
    float2 normal : TEXCOORD11;
    float2 shadowOffset : TEXCOORD12;
    float shadowRadius : TEXCOORD13;
    float4 shadowColor : TEXCOORD14;
};

cbuffer ViewUniforms : register(b0, space1) {
    float4x4 viewProjection;
};

struct VertexOutput {
    float4 sourceColor : COLOR0;
    float4 shadowColor : COLOR1;
    float4 materialColor : COLOR2;
    float3 shape : TEXCOORD0;
    float2 local : TEXCOORD1;
    float2 shadowLocal : TEXCOORD2;
    float mode : TEXCOORD3;
    float shadowRadius : TEXCOORD4;
    float4 position : SV_Position;
};

VertexOutput vertex_main(VertexInput input) {
    const float2 localOffset = float2(
        dot(input.shadowOffset, input.axis),
        dot(input.shadowOffset, input.normal)
    );
    const float2 extent = abs(input.local);
    const float support = ceil(input.shadowRadius) + 1.0;
    const float2 minimum = min(-extent, -extent + localOffset - support);
    const float2 maximum = max(extent, extent + localOffset + support);
    const float2 expandedLocal = float2(
        input.local.x < 0.0 ? minimum.x : maximum.x,
        input.local.y < 0.0 ? minimum.y : maximum.y
    );
    const float2 canvasPosition = input.center +
        input.axis * expandedLocal.x + input.normal * expandedLocal.y;
    const float2 worldPosition = input.modelX * canvasPosition.x +
        input.modelY * canvasPosition.y + input.modelTranslation;

    VertexOutput output;
    output.position = mul(
        viewProjection,
        float4(worldPosition, input.modelDepth, 1.0)
    );
    output.sourceColor = input.color;
    output.shadowColor = input.shadowColor;
    output.materialColor = input.materialColor;
    output.shape = input.shape;
    output.local = expandedLocal;
    output.shadowLocal = expandedLocal - localOffset;
    output.mode = input.position.z;
    output.shadowRadius = input.shadowRadius;
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

float shape_edge(float2 coordinate, float3 shape, float mode) {
    float distance;
    if (shape.z < -1.5) {
        distance = line_distance(coordinate, shape.xy, shape.z);
    } else if (shape.z < -0.5) {
        distance = length(coordinate) - shape.x;
    } else {
        distance = rounded_box_distance(coordinate, shape.xy, shape.z);
    }
    if (mode > 0.0 && shape.z >= -1.5) {
        return abs(distance) - mode * 0.5;
    }
    return distance;
}

float erf_approximation(float value) {
    const float signValue = value < 0.0 ? -1.0 : 1.0;
    const float x = abs(value);
    if (x >= 1.75) { return signValue; }
    const float squared = x * x;
    const float polynomial = 1.128269906 + squared * (-0.374057723 +
        squared * (0.106547438 + squared * (-0.019925391 +
        squared * 0.001756081)));
    return signValue * x * polynomial;
}

float blurred_coverage(float edge, float radius) {
    if (radius <= 0.0) {
        return saturate(0.5 - edge / max(fwidth(edge), 0.0001));
    }
    const float sigma = max(radius / 3.0, 1.0 / 3.0);
    return saturate(0.5 * (1.0 - erf_approximation(
        edge / (sigma * 1.41421356237)
    )));
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    const float sourceEdge = shape_edge(input.local, input.shape, input.mode);
    const float sourceCoverage = saturate(
        0.5 - sourceEdge / max(fwidth(sourceEdge), 0.0001)
    );
    const float shadowEdge = shape_edge(
        input.shadowLocal,
        input.shape,
        input.mode
    );
    const float shadowCoverage = blurred_coverage(
        shadowEdge,
        input.shadowRadius
    );

    const float sourceAlpha = input.sourceColor.a * sourceCoverage;
    const float shadowAlpha = input.sourceColor.a * input.shadowColor.a *
        shadowCoverage * (1.0 - sourceAlpha);
    const float outputAlpha = (sourceAlpha + shadowAlpha) *
        input.materialColor.a;
    if (outputAlpha <= 0.0) { return float4(0.0, 0.0, 0.0, 0.0); }
    const float3 premultiplied = (
        input.sourceColor.rgb * sourceAlpha +
        input.shadowColor.rgb * shadowAlpha
    ) * input.materialColor.rgb * input.materialColor.a;
    return float4(premultiplied / outputAlpha, outputAlpha);
}
