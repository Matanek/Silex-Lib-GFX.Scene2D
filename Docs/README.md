# GFX.Scene2D

`GFX.Scene2D` owns the data that a user or alternative renderer must name to
describe a 2D scene: `Transform`, `Camera`, `Canvas`, `Sprite`,
`Grid`, and `Sampling`. The domain already carries the dimension, so
declarations remain unsuffixed.

```silex
use GFX.Canvas
use GFX.Color
use GFX.Components
```

`Components.Canvas` places retained `GFX.Canvas` content through a
`Components.Transform2D`. World coordinates are the default and use a centered
camera supplied by Scene2D when the application does not create one. An
explicit `Components.Camera2D` replaces that default when the scene needs to
move, zoom, or select a camera.

The Scene2D world follows the same spatial convention as Scene3D: X points
right and Y points up. Authored `GFX.Canvas` content keeps its natural
top-left, Y-down drawing coordinates and Scene2D orients it automatically when
placing it in the world. `Camera.project()` returns top-left, Y-down viewport
coordinates suitable for pointer input and window APIs.

The same component can use logical window coordinates through
`Components.CanvasSpace.viewport`. Its `anchor` selects a point in the
viewport. This screen-space mode also remains top-left and Y-down, while
`Transform2D.position` is the offset that animation and other systems modify.
Canvases that share one authored value also share their cached geometry and
are rendered as instances.

Equivalent vector geometry is interned by the renderer even when placements
come from distinct authored Canvas objects. Per-entity color, layer, pivot, and
size remain independent without requiring a batching API or shared-cache
ceremony in application code.

`Canvas.replace(...)` is also incremental. A changing Canvas reuses one
per-entity GPU geometry allocation. Text commands retain independent cache
identities, so a changing value updates one small texture while static labels
keep both their glyph coverage and uploaded textures. Dragging a control
therefore does not grow the renderer caches or rerasterize every label around
it.

The built-in renderer indexes sprite and text texture identities directly.
Its lookup cost is therefore linear in the visible draws even for terminal-like
Canvas content with many retained text layers. The centralized
[UpdatingTextLayers2D](https://github.com/Matanek/Silex-Benchmarks/blob/main/Sources/UpdatingTextLayers2D.sx)
workload covers fixed-grid row updates separately from the
[Boids2D](https://github.com/Matanek/Silex-Benchmarks/tree/main/Sources/Boids2D)
geometry and ECS benchmark.

```silex
use GFX.Canvas
use GFX.Color
use GFX.Components
use GFX.ECS
use STD.Math

var drawing = Canvas()
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D(position:Math.Vec2(40.0, 20.0)))
    ..with(Components.Canvas(drawing, 320, 180)..color = Color.cyan_400())
)
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
`space` selects world or viewport presentation, while `Transform2D` carries
position, rotation, and scale in both cases. `Scene2D.Plugin` installs
its ECS, asset, and rendering dependencies and registers the Scene2D pass in
the public `GFX.Rendering.Renderer` frame graph. An alternative renderer can
read `snapshot()` and `revision()` from the placement component instead of
depending on the built-in GPU cache.

Its built-in shaders live directly under `Shaders/`: `Drawing.hlsl`,
`Grid.hlsl`, and `Sprite.hlsl`. They are neither moved into `GFX.Rendering` nor
treated as a mandatory API. An extension can read the public scene data and
provide its own shader with `GFX.GPU.ShaderProgram.hlsl`.
