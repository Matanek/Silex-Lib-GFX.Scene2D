cbuffer GridUniforms : register(b0, space1) {
    float4x4 inverseViewProjection;
    float4 minorColor;
    float4 majorColor;
    float4 xAxisColor;
    float4 yAxisColor;
    float4 settings;
};

struct VertexOutput {
    float2 clip : TEXCOORD0;
    float4 position : SV_Position;
};

VertexOutput vertex_main(uint vertexId : SV_VertexID) {
    float2 clip = float2(
        vertexId == 1 ? 3.0 : -1.0,
        vertexId == 2 ? 3.0 : -1.0
    );
    VertexOutput output;
    output.clip = clip;
    output.position = float4(clip, 0.0, 1.0);
    return output;
}

float line_coverage(float coordinate, float spacing, float width) {
    float scaled = coordinate / spacing;
    float distanceToLine = abs(frac(scaled - 0.5) - 0.5);
    float footprint = max(fwidth(scaled), 0.000001);
    float pixelDistance = distanceToLine / footprint;
    return 1.0 - smoothstep(width * 0.5, width * 0.5 + 1.0, pixelDistance);
}

float axis_coverage(float coordinate, float width) {
    float footprint = max(fwidth(coordinate), 0.000001);
    float pixelDistance = abs(coordinate) / footprint;
    return 1.0 - smoothstep(width * 0.5, width * 0.5 + 1.0, pixelDistance);
}

float4 fragment_main(VertexOutput input) : SV_Target0 {
    float4 world = mul(inverseViewProjection, float4(input.clip, 0.0, 1.0));
    float2 position = world.xy / world.w;
    float worldPerPixel = max(length(ddx(position)), length(ddy(position)));
    float continuousLevel = clamp(
        log(max(worldPerPixel * 12.0 / settings.x, 0.000001)) / log(settings.y),
        -8.0,
        8.0
    );
    float level = floor(continuousLevel);
    float transition = frac(continuousLevel);
    float minorSpacing = settings.x * pow(settings.y, level);
    float majorSpacing = minorSpacing * settings.y;
    float coarseSpacing = majorSpacing * settings.y;
    float minor = max(
        line_coverage(position.x, minorSpacing, settings.z),
        line_coverage(position.y, minorSpacing, settings.z)
    );
    float major = max(
        line_coverage(position.x, majorSpacing, settings.z),
        line_coverage(position.y, majorSpacing, settings.z)
    );
    float coarse = max(
        line_coverage(position.x, coarseSpacing, settings.z),
        line_coverage(position.y, coarseSpacing, settings.z)
    );

    float minorWeight = minor * (1.0 - transition);
    float4 middleColor = lerp(majorColor, minorColor, transition);
    float3 gridColor = minorColor.rgb;
    float gridAlpha = minorColor.a * minorWeight;
    gridColor = lerp(gridColor, middleColor.rgb, major);
    gridAlpha = max(gridAlpha, middleColor.a * major);
    float coarseWeight = coarse * transition;
    gridColor = lerp(gridColor, majorColor.rgb, coarseWeight);
    gridAlpha = max(gridAlpha, majorColor.a * coarseWeight);
    float4 color = float4(gridColor, gridAlpha);

    float xAxis = axis_coverage(position.y, settings.w);
    float yAxis = axis_coverage(position.x, settings.w);
    color = lerp(color, xAxisColor, xAxis);
    color = lerp(color, yAxisColor, yAxis);
    color.a = max(color.a, max(xAxis * xAxisColor.a, yAxis * yAxisColor.a));
    if (color.a <= 0.001) discard;
    return color;
}
