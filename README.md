# GFX.Scene2D

`GFX.Scene2D` provides retained 2D scenes for GFX: transforms, cameras,
sprites, vector Canvas placement, viewport controls, grids, and the built-in
GPU renderer.

```text
silex install GFX.Scene2D
```

```silex
use GFX.Canvas
use GFX.Components
use GFX.ECS
use GFX.Plugins
use STD.Math

var drawing = Canvas()
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D(position:Math.Vec2(40.0, 20.0)))
    ..with(Components.Canvas(drawing, 320, 180))
)

application.add_plugin(Plugins.Scene2D())
```

The same `Components.Canvas` component can render in the 2D world or in
logical viewport coordinates. Scene2D contributes its owned declarations to
the `GFX.Components`, `GFX.Plugins`, and `GFX.Resources` catalogs without
changing their public names.

Replacing a Canvas is incremental: mutable geometry reuses a bounded GPU
allocation, and each text command keeps a stable texture identity. Changing a
single label rerasterizes and uploads only that label; unchanged text is
neither rerasterized nor reuploaded.

Image and text cache identities are indexed directly, so preparing a frame is
linear in the visible layers instead of repeatedly scanning every retained
texture. The centralized
[UpdatingTextLayers2D](https://github.com/Matanek/Silex-Benchmarks/blob/main/Sources/UpdatingTextLayers2D.sx)
benchmark exercises 1,500 fixed-grid cells retained as 30 changing row layers;
[Boids2D](https://github.com/Matanek/Silex-Benchmarks/tree/main/Sources/Boids2D)
remains the geometry/ECS guard.

The package owns its shaders, tests, and documentation. Public performance
campaigns live in `Silex-Benchmarks`, while the visual
[analog clock](https://github.com/Matanek/Silex-Examples/blob/main/Sources/AnalogClock.sx)
lives in `Silex-Examples`. See [Docs/README.md](Docs/README.md) for coordinates,
Canvas placement, camera behavior, and renderer extension points.
