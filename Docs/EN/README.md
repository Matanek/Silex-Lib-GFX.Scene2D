# Build a retained scene with GFX.Scene2D

`GFX.Scene2D` owns the data that a user or alternative renderer must name to
describe a 2D scene: `Transform`, `Camera`, `Canvas`, `Sprite`, `Grid`, and
`Sampling`. The domain already carries the dimension, so declarations remain
unsuffixed.

[Lire cette documentation en français.](../FR/README.md)

## Install the package

```text
silex install GFX.Scene2D
```

GFX.Scene2D requires Silex 0.43.0 or newer.

## Place Canvas content

`Components.Canvas` places a retained `GFX.Canvas` drawing through a
`Components.Transform2D`. This fragment assumes an existing `world:ECS.World`:

```sx
use GFX.Canvas
use GFX.Color
use GFX.Components
use GFX.ECS
use STD.Math

var drawing = Canvas()
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D(position:Math.Vec2(40.0, 20.0)))
    ..with(Components.Canvas(drawing)..color = Color.cyan_400())
)
```

This form defines no frame: the drawing's `(0, 0)` point coincides with the
`Transform2D` position, and geometry may extend in every direction. `size` and
the normalized pivot belong to framed placement and do not alter this local
placement.

`Components.Canvas(drawing, width, height)` preserves the historical behavior
when a reference rectangle is useful for resizing, pivoting, or clipping text.

World coordinates are the default, with a centered camera created by Scene2D
when the application provides none. An explicit `Components.Camera2D` replaces
that camera to move, zoom, or select the viewpoint.

The Scene2D world follows Scene3D's spatial convention: X points right and Y
points up. `GFX.Canvas` content keeps its natural top-left, Y-down drawing
coordinates; Scene2D orients it automatically. `Camera.project()` returns the
same viewport coordinates suitable for pointer and window APIs.

## Place an interface in the viewport

The same component uses logical window coordinates with
`Components.CanvasSpace.viewport`. Its `anchor` selects a viewport point,
while `Transform2D.position` remains the offset that animation can change:

```sx
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D())
    ..with(Components.Canvas(drawing, 320, 180)
        ..space = Components.CanvasSpace.viewport
        ..anchor = Math.Vec2(0.5)
        ..pivot = Math.Vec2(0.5)
    )
)
```

`Components.Canvas` is the single retained-vector placement component. Its
`space` selects world or viewport presentation; `Transform2D` carries position,
rotation, and scale in both cases.

## Choose text rendering

Canvas text keeps `CanvasTextMode.coverage` by default. This path rasterizes
each glyph shaped by `GFX.Font` with hinting on first use, stores it in an R8
GPU atlas, then draws visible occurrences as instanced quads. A cold scroll no
longer recomposes one RGBA texture per line. It suits small sizes, terminals,
and dense interfaces. `coverage_density` multiplies the window's physical
density and must remain strictly positive:

```sx
var label = Components.Canvas(drawing, 320, 80)
label.text_mode = Scene2D.CanvasTextMode.coverage
label.coverage_density = 2.0
```

`CanvasTextMode.vector` consumes the same `TextLayer` glyph runs and outlines.
It fails explicitly when a visible glyph has no outline and never silently
drops that glyph. `automatic` selects vector rendering when every non-empty
glyph is vectorizable and otherwise falls back to faithful coverage. The
choice does not depend on a hidden zoom threshold: requesting hinted coverage
remains explicit and deterministic.

```sx
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D())
    ..with(Components.Canvas(drawing, 320, 80)
        ..text_mode = Scene2D.CanvasTextMode.vector
    )
)
```

The vector path applies the non-zero fill rule across all contours of a glyph,
so counters in `O` and `B` remain open. Normalized meshes are shared across
sizes, colors, and placements. Three stable detail classes cover small text,
ordinary drawing, and strong magnification; remaining in one class does not
retessellate. Color, translation, rotation, and scale update only the GPU
instance.

## Render an analytic shadow

The built-in renderer has a direct GPU path for a Canvas layer containing
exactly one `Effect.shadow(...)` and exactly one analytic primitive: rectangle,
rounded rectangle, circle, or line. Its brush alpha must be spatially uniform.
The shader evaluates both the shape and its Gaussian blur inside an expanded
quad; it creates no CPU image, effect texture, or offscreen pass. Translation,
rotation, and scale, including non-uniform scale, remain instance data. Changing
placement or shadow parameters therefore does not rebuild shared geometry.

This narrow contract is intentional. A layer with several primitives, a path,
an image, a spatially varying brush alpha, or text is not eligible. This applies
to both vector and coverage `GFX.Font` text modes: text remains vector or
rasterizable according to the component choice, but its shadow requires the
general effect compositor. Until that compositor is installed, Scene2D fails
explicitly with `Canvas filtered layer is not eligible for the analytic shadow
path` instead of dropping the effect.

## Apply a Canvas placement filter

`CanvasFilter` is a Scene2D escape hatch applied to the Canvas final texture
after its portable effects and before placement tint. It therefore requires a
bounded GPU isolation pass and does not replace the analytic geometry shader.
Two placements sharing the drawing, filter, and density class also share the
source and filtered result even when translation, rotation, or `color` differ.

```sx
let program = GPU.ShaderProgram.hlsl(file:"Shaders/Heatmap.hlsl")
var filter = Scene2D.CanvasFilter(program)
var placement = Scene2D.Canvas(drawing, 320, 180)
placement.filter = filter
```

The `CanvasFilter.v1` ABI requires `vertex_main` and `fragment_main`. Vertex
input is `float2 position : POSITION0` followed by `float2 uv : TEXCOORD0`; the
output carries `float4 position : SV_Position` and `float2 uv : TEXCOORD0`.
The shared `b0, space1` cbuffer, bound to both stages, is exactly 96 bytes:
`float4x4 clipFromUnit`, then `logicalOrigin`, `logicalSize`, `pixelSize`, and
`inversePixelSize` as `float2` values. The premultiplied linear RGBA texture and
its clamped linear sampler are `t0/s0, space2`. The fragment returns a
premultiplied `float4 : SV_Target0`.

Positions and UVs cover `[0, 1]²` with a top-left origin. Integer texel center
`i` is `(i + 0.5) * inversePixelSize`. The texture has no hidden padding and the
filter preserves its bounds and dimensions. The vertex shader computes exactly
`mul(clipFromUnit, float4(input.position, 0.0, 1.0))` and forwards the UV.

An optional fragment `b1, space1` cbuffer may contain 16 to 4096 bytes in
16-byte blocks. Pass those bytes to the constructor and call `replace(bytes)`:
the revision advances and only the filter pass reruns. The block size remains
fixed. `CanvasFilter.compatibility(program, parameter_size)` preflights entry
points and resource counts with a diagnostic without creating the filter. No
extra texture, storage resource, depth write, or custom raster state belongs to
v1.

## Understand retention and caches

The component retains the identity of the `GFX.Canvas.Canvas` it receives. If
the producer later calls `clear()`, `paint(...)`, or another operation that
changes that drawing, Scene2D observes its new revision before the next render.
Animating commands on the same Canvas instance therefore requires neither
`world.update(...)` nor `replace(...)`.

Placements that share this instance also share cached geometry and render as
instances. The built-in renderer also interns equivalent geometry from
distinct Canvas values. Color and layer remain per-entity; pivot and size apply
to framed placements.
A placement that remains static keeps the `Snapshot` already cached by its
drawing, so creating several thousand placements from the same instance only
vectorizes the content once. The `Canvas.Prepared` mesh pair is allocated only
after the first change observed on that placement.

`Canvas.replace(...)` changes the component's source when the application wants
to provide another Canvas instance. After that first mutation, geometry reuses
a pair of retained CPU meshes and a bounded GPU allocation, while every text
command retains an independent cache identity. An animated frame therefore
rewrites mesh values without rebuilding its capacities. Changing only a label
uploads neither geometry nor the other text layers.

A `Canvas.ImagePaint` follows the same principle. Scene2D retains the mask mesh
separately from the texture indexed by ImagePaint identity. An unchanged frame
uploads nothing; `ImagePaint.replace(...)` uploads only that texture and keeps
the rectangle, circle, or path buffer. The shader applies `fit` or `tile` in
Canvas-local coordinates before evaluating the analytic mask. Rotation and
non-uniform scale therefore remain instance properties rather than reasons to
rebuild geometry.

Sprite and text texture identities are indexed directly, so frame preparation
remains linear in visible draws. The vector cache retains at most 2,048 glyph
meshes and 256 prepared layers. After warm-up, static vector text performs no
new shaping, decomposition, tessellation, rasterization, or pixel upload; the
coverage path retains hinted glyphs in at most four 2,048 × 2,048 R8 atlas
pages (16 MiB maximum allocation) with a bounded direct table. Canvas-local
quad clipping preserves framed content; coverage that cannot fit the atlas
falls back to the layer-texture path. A rectangular clip attached to a Canvas
text command crops each visible atlas quad and its UV region in Canvas-local
coordinates. Clipped text uses the coverage path even when the component
otherwise requests vector outlines, preserving an exact edge without
rebuilding glyph meshes or allocating an offscreen texture while scrolling. The
[UpdatingTextLayers2D](https://github.com/Matanek/Silex-Benchmarks/blob/main/Sources/UpdatingTextLayers2D.sx)
and [Boids2D](https://github.com/Matanek/Silex-Benchmarks/tree/main/Sources/Boids2D)
benchmarks guard text and geometry/ECS paths respectively.

## Produce a filtered Canvas surface

`CanvasSurfaceRenderer` renders a Canvas snapshot into a bounded GPU texture
that another pipeline can sample. The service belongs to the `GPU.Device`
provided at construction. `CanvasSurface` strongly retains the result and only
exposes its opaque `GPU.Texture` value through `texture()` so consumers can
build a `GPU.TextureRegion` or bind it to a sampler; no native handle or
internal Scene2D cache crosses the API.

```sx
use GFX.Canvas
use GFX.GPU
use GFX.Scene2D
use STD.Math

var device = GPU.Device()
var surfaces = Scene2D.CanvasSurfaceRenderer(device)
var snapshot = drawing.snapshot(320, 180)
var surface = surfaces.render(
    snapshot,
    Canvas.Rect(Math.Vec2(), Math.Vec2(320.0, 180.0)),
    2.0,
    Scene2D.CanvasTextMode.automatic
)

pass.fragment_sampler(0, surface.texture(), sampler)
```

The published texture contains linear premultiplied RGBA. `bounds()`,
`width()`, `height()`, and `density()` relate its logical Canvas frame to its
texels. The source renderer uses bounded 4× MSAA, resolves color, then applies
separable blurs, opacity, and shadows through intermediate RGBA16F targets; the
last target returns to sampleable RGBA8. Concave paths, vector text, hinted
glyphs from the R8 atlas, images, and nested groups preserve author order. No
SDL_ttf text or RGBA line upload is reintroduced.

The cache distinguishes content identity and revision, logical frame, text
mode, and a density class rounded upward to the next quarter. A rigid placement
therefore reuses its local surface; crossing a density class, mutating content,
or replacing a referenced resource invalidates only the required entries. When
dimensions and formats remain identical, a new revision rewrites retained
textures without another allocation. On the Scene2D path, source, effect, and
filter passes for every surface in a frame are also recorded into one command
buffer before submission; standalone `CanvasSurfaceRenderer.render` keeps its
immediate submission contract.
`render_count()`, `cache_hit_count()`, `graph_pass_count()`,
`texture_allocation_count()`, and `texture_byte_count()` report that work and
currently cache-resident memory; a surface still retained by a consumer is not
counted after eviction. A new revision replaces the obsolete entry for the
same group even when its bounds changed. Text counters distinguish vector tessellation, R8
glyph rasterization, and uploaded alpha pixels from `rgba_upload_count()`,
which remains zero on this path.
`content_geometry_upload_count()` separately counts content-renderer mesh
transfers so mutation workloads can verify that they remain proportional.

`render_exact` instead preserves the supplied density and guarantees
`ceil(frame * density)` dimensions. Fixed-resolution consumers such as
`Scene3D.CanvasPanel` use this variant; `render` keeps quarter-step classes for
adaptive Scene2D effects.

A surface remains attached to its device. `invalidate()` releases cache
residency and immediately invalidates every surface from that generation; a
texture still owned by an old surface is released with that surface but can no
longer be borrowed. `replace_device()` performs that invalidation before
adopting a new device. The next request
publishes a new revision and device generation. A non-finite frame or density,
a zero dimension, missing sampleable RGBA8/4× MSAA or RGBA16F support, and a
target exceeding 16,384 texels on either axis all fail explicitly. Scene2D
never hides these cases behind full-window CPU rasterization.

Cost depends on texel area, source MSAA, pass count, and filter radius. Large
dynamic groups and full-screen effects are therefore substantially more
expensive than small reused static surfaces. This API does not provide a
backdrop blur, which requires a separate dependency on content rendered
earlier in the frame.

## Extend the renderer

`Plugins.Scene2D` installs its ECS, asset, and rendering dependencies and
registers its pass in the public `GFX.Rendering.Renderer` frame graph. An
alternative renderer can read `snapshot()` and `revision()` from the placement
component. The built-in renderer follows the incremental `Canvas.Prepared`
path without materializing that complete snapshot every frame.

With `Plugins.BundleManager`, install `Plugins.Scene2D()` on the Application so
the window, GPU, assets, renderer, and its caches remain alive across
transitions. `Scene2D` automatically extends Bundles with the same Plugin: its
systems read each local `World` without another `Content` type and without
rebuilding unchanged Canvas geometry.

```sx
use GFX.Plugins

application
    ..add_plugin(Plugins.Scene2D())
    ..add_plugin(Plugins.BundleManager(bundle))
```

A self-contained Bundle may instead install `Plugins.Scene2D()` directly; it
then owns its window and rendering stack when the parent does not provide them.

The `Drawing.hlsl`, `AnalyticShadow.hlsl`, `CanvasEffect.hlsl`,
`CoverageGlyph.hlsl`, `ImageDrawing.hlsl`, `Grid.hlsl`, and `Sprite.hlsl`
shaders belong to this package. They are not a mandatory API; an extension can
read public scene data and provide its own `GPU.ShaderProgram.hlsl`.

The visual [AnalogClock](https://github.com/Matanek/Silex-Examples/blob/main/Sources/AnalogClock.sx)
demonstration belongs to Silex-Examples.
