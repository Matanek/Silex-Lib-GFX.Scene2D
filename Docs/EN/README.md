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

`Camera.unproject()` performs the inverse operation for hit testing. It uses
the same viewport fallback as `project()` and returns `null` when the transform
cannot be inverted.

## Bound a navigable camera

The `Plugins.ViewportCamera2D` controller accepts content bounds in world
units. It centers an axis that is smaller than the viewport and clamps a larger
axis from the current zoom. `overscroll` adds an optional world-space margin at
the extremes and remains independent from physical display density.

```sx
use GFX.Input
use GFX.Plugins
use STD.Math

let controls = Plugins.ViewportCamera2DControls(
    pan:Input.MouseButton.middle,
    scroll:Plugins.ViewportCamera2DScroll.pan
)
let camera_plugin = Plugins.ViewportCamera2D(
    Plugins.ViewportCamera2D.Settings(
        controls:controls,
        overscroll:Math.Vec2(100.0)
    )
)

controller.set_limits(Math.Rect(0.0, 0.0, board_width, board_height))
let world_point = camera.unproject(pointer, transform, window.size())!
controller.clear_limits()
```

Scroll keeps zooming by default. Explicit `pan` consumes both axes and applies
`pan_sensitivity / zoom`, like the configured drag. A resize, zoom change, or
bounds change immediately reclamps both current and desired positions, so
smoothing never publishes a persistent overshoot.

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

The `Drawing.hlsl`, `Grid.hlsl`, and `Sprite.hlsl` shaders belong to this
package. They are not a mandatory API; an extension can read public scene data
and provide its own `GPU.ShaderProgram.hlsl`.

The visual [AnalogClock](https://github.com/Matanek/Silex-Examples/blob/main/Sources/AnalogClock.sx)
demonstration belongs to Silex-Examples.
