# Changelog

## [Unreleased]

- Keep clipped Canvas surfaces alive until their enclosing preparation or frame
  finishes. Cache pressure no longer rebuilds a child through an active parent
  renderer, which could stretch table headers during hover. Temporary entries
  cover a live working set larger than the 128-entry idle cache.

- Adopts one `Result` declaration: an ordinary call returns the value or
  stops the program on failure; `try call()` keeps the `Result`. Existing calls
  storing results and propagating failures are made explicit. This revision
  requires the development toolchain with these `try` semantics; publication
  must coordinate compiler and package versions.

- Glyph-instance uploads preserve transfer and drawing buffers already referenced by GPU passes. Clipped Canvas rows remain complete when multiple surfaces share a deferred batch, including hover and selection repaints.

- Compose clipped Canvas groups through retained GPU surfaces after child effects. Empty groups are skipped; changed bounds invalidate their surface while unchanged groups remain cached.

- Vector caches distinguish each glyph face for Canvas lines using a fallback font.

- Fixed backgrounds and borders retaining old geometry after resizing reused Canvas drawings. The cache tracks each content revision; unchanged drawings do not trigger another upload.

- Added `Parallax` for sprites and tile maps: X/Y factors, origin, and repetition in world coordinates. Visible tile map copies share their preparation and one GPU draw; ECS positions remain unchanged.

- Fixed atlas pixels leaking between sprite and tilemap regions during fractional camera movement. Shaders clamp lookups to the selected region without shrinking UVs; an offscreen GPU regression covers 4× MSAA and both sampling modes.

- Fixed coverage text density to account for camera zoom, Canvas scale and resizing, avoiding enlargement of glyphs rasterized at too small a size.

- Added TilePatch for nine-tile surfaces and distinct content revisions across maps and copies. Cache visible CPU instances by content, visible range and atlas dimensions, with GPU tests for scrolling and edits.
