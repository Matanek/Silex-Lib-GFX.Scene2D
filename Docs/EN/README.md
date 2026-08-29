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

GFX.Scene2D requires Silex 0.39.0 or newer.

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

`Canvas.replace(...)` changes the component's source when the application wants
to provide another Canvas instance. In either case, mutable geometry reuses a
bounded GPU allocation and every text command retains an independent cache
identity. Changing a label therefore rerasterizes and uploads only that label.

Sprite and text texture identities are indexed directly, so frame preparation
remains linear in visible draws. The
[UpdatingTextLayers2D](https://github.com/Matanek/Silex-Benchmarks/blob/main/Sources/UpdatingTextLayers2D.sx)
and [Boids2D](https://github.com/Matanek/Silex-Benchmarks/tree/main/Sources/Boids2D)
benchmarks guard text and geometry/ECS paths respectively.

## Extend the renderer

`Scene2D.Plugin` installs its ECS, asset, and rendering dependencies and
registers its pass in the public `GFX.Rendering.Renderer` frame graph. An
alternative renderer reads `snapshot()` and `revision()` from the placement
component instead of depending on the built-in GPU cache.

The `Drawing.hlsl`, `Grid.hlsl`, and `Sprite.hlsl` shaders belong to this
package. They are not a mandatory API; an extension can read public scene data
and provide its own `GPU.ShaderProgram.hlsl`.

The visual [AnalogClock](https://github.com/Matanek/Silex-Examples/blob/main/Sources/AnalogClock.sx)
demonstration belongs to Silex-Examples.
