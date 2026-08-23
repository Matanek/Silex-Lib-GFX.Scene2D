# Boids C++/Silex

This directory contains the two witnesses used to compare the cost of GFX's
public Scene2D path with a C++23 implementation that calls SDL3 directly.

Both programs preserve the same quadratic algorithm, one flock snapshot per
frame, the same simulation constants, a 960 × 640 logical window requesting a
high-density framebuffer, immediate presentation without VSync, and a
five-second measurement period. Pass `4000` explicitly to both executables for
a valid comparison. Always compare the reported logical and pixel dimensions;
a run whose presentation mode or dimensions differ is invalid.

## Silex/GFX

From the SilexProject workspace root:

```sh
Silex/Toolchain/zig-out/bin/silex compile \
    Packages/GFX.Scene2D/Benchmarks/Boids/Silex.sx \
    -o /private/tmp/gfx-boids-silex
/private/tmp/gfx-boids-silex 4000
```

The output has this form:

```text
SILEX_GFX_BOIDS count=4000 present=immediate fps=80.0 window=960.0x640.0 pixels=1920.0x1280.0 scale=2.0 density=2.0
```

## C++23/SDL3

The C++ witness requires an SDL3 development installation discoverable by
CMake.

```sh
cmake \
    -S Packages/GFX.Scene2D/Benchmarks/Boids/Cpp \
    -B /private/tmp/gfx-boids-cpp \
    -DCMAKE_BUILD_TYPE=Release
cmake --build /private/tmp/gfx-boids-cpp --config Release
/private/tmp/gfx-boids-cpp/BoidsCppSDL 4000
```

The output has this form:

```text
CPP_SDL_BOIDS count=4000 present=immediate fps=86.0 window=960x640 pixels=1920x1280 scale=2.0 density=2.0
```

## Comparison protocol

Compile before starting the series, close other graphical workloads, perform
several warm-up runs, and then alternate between the two executables. Compare
at least five results per version and use the medians. Compilation time is not
part of the FPS measurement.

The Silex witness runs through the ECS, injected systems, and GFX's public
Scene2D API. The C++ witness stores its boids in a `std::vector` and calls SDL3
directly. It is therefore a performance witness, not a layer-for-layer
comparison.
