# Boids performance baselines

This directory archives raw output from the three witnesses in
[`../Boids`](../Boids). The records are performance controls, not correctness
tests or portable timing claims.

## 2026-08-26 contended macOS ARM64 observation

[`2026-08-26-arm64-boids.log`](2026-08-26-arm64-boids.log) compares the three
4,000-boid executables on the same Apple M3 Pro host. All programs used
immediate presentation, a 960 x 640 logical window, a 1920 x 1280 framebuffer,
and a five-second measurement interval. One warm-up process per executable was
discarded, then seven isolated processes per witness were recorded in rotating
Silex, C++ architectural, C++ direct order.

The Codex agent remained active during this capture. A later user-run Silex
process reached 84.7 FPS, while a one-round runner smoke reached the expected
higher C++ ranges. This file is therefore retained as evidence of scheduling
sensitivity and raw historical output, not as the accepted performance
baseline. Replace its acceptance role with a capture produced from an external
terminal after closing Codex and other competing workloads.

| Witness | Median | MAD | Range | Relative to C++ architectural |
| --- | ---: | ---: | ---: | ---: |
| Silex/GFX | 81.664 FPS | 0.14% | 81.265-81.776 FPS | -3.66% |
| C++ architectural | 84.763 FPS | 0.11% | 84.535-85.065 FPS | reference |
| C++ direct | 84.110 FPS | 0.04% | 84.019-84.299 FPS | -0.77% |

The architectural C++ witness is the primary comparison because it matches
the ECS, SDL_GPU, shader, instancing, presentation, and data-layout costs of
the public Scene2D path. The direct SDL_Renderer witness exercises a different,
lower-level path and is retained only as a secondary throughput control.

The Silex median is 2.28% below the 83.573 FPS median archived by the
GFX.Physics Spec 13 acceptance session on the same host and compiler revision.
Because this capture had a competing workload and that older session used
another Scene2D revision, the difference does not by itself establish a code
regression.

## Capture protocol

Build all three executables before starting the measurements, close other
graphical workloads, and pass `4000` explicitly. Discard one warm-up process
for each executable, then rotate between the three executables for at least
seven recorded processes each. Reject any run whose count, presentation mode,
logical window, pixel dimensions, scale, or density differs from the archived
configuration. Compare medians and report median absolute deviation (MAD) as a
percentage of the median.

The package-owned runner applies this protocol and produces a timestamped log:

```text
Packages/GFX.Scene2D/Benchmarks/Boids/RunComparison.sh --wait
```

Future records should retain the raw sentinel lines and enough host, compiler,
package, and dependency revisions to reproduce the configuration. Do not
archive serial numbers, hardware UUIDs, usernames, or absolute home paths.
