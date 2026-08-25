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
allocation, and unchanged text is neither rerasterized nor reuploaded.

The package owns its shaders, examples, tests, benchmark, and documentation.
See [Docs/README.md](Docs/README.md) for coordinates, Canvas placement, camera
behavior, and renderer extension points.
