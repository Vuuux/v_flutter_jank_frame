# v_flutter_jank_frame by V

Flutter demo app to show how to detect jank in DevTools and how targeted changes improve frame performance.

## What this app does

This app is a performance playground for profiling UI-thread jank in Flutter. It includes:

- Two list modes for A/B comparison (`Not Optimized` and `Optimized`)
- A global `compute()` toggle that affects both lists
- Live frame metrics based on `FrameTiming`
- A baseline intensity slider to amplify jank for demo clarity

Everything is implemented in `lib/main.dart`.

## UI controls and behavior

<img width="540" height="1170" alt="Screenshot_20260728_025053" src="https://github.com/user-attachments/assets/c9016c64-a34b-4eb7-a784-3a25573284ed" />

### Mode switch

- `Not Optimized`: intentionally janky baseline.
- `Optimized`: same source list path with targeted optimizations.

### Jank intensity slider

- Increases heavy CPU work pressure in baseline calculations.
- Higher values make missed frames easier to observe.

### `Use compute() precomputed data (both lists)`

- **ON**:
  - Runs score precomputation on a background isolate via `compute()`.
  - Both lists use cached scores when ready.
  - Optimized mode shows `Preparing compute() result...` while waiting, avoiding a UI-thread fallback.
- **OFF**:
  - Clears cached scores.
  - Both lists compute score during build again.

### `Reset frame stats`

- Resets tracked frame counters so each profile pass starts clean.

## Runtime metrics shown in-app

Top status panel:

- Total tracked frames
- Frames that miss 60fps budget
- Average build+raster time

Extra baseline-only diagnostics:

- Current scroll offset (updated with `setState` on scroll)
- Scroll-tick CPU cost signal

## Behavior differences by mode

### Not Optimized mode

- Calls `setState` on every scroll tick (rebuild churn).
- Runs expensive sync CPU work in `itemBuilder`.
- Uses oversized network image source (`4000x3000`).
- Avoids repaint boundary isolation.

### Optimized mode (derived from baseline)

- Avoids scroll-driven `setState` churn.
- Uses list hints (`itemExtent`, `scrollCacheExtent`) to reduce layout overhead.
- Uses smaller image source (`1280x720`) and decode-size hints (`cacheWidth`, `cacheHeight`).
- Uses lower image filter quality.
- Wraps rows in `RepaintBoundary` to reduce repaint scope.
- Uses precomputed values when compute is enabled.

## How compute() is represented

- Sync and isolate paths use the same heavy score algorithm for fair comparison.
- `compute()` runs that algorithm in a background isolate.
- With compute-enabled cached results, rows avoid running heavy CPU work in `itemBuilder`.

## Run

```zsh
cd /Users/loc_huu.h/StudioProjects/flutter_jank_frame
flutter run --debug
```

For realistic performance results, use profile mode:

```zsh
cd /Users/loc_huu.h/StudioProjects/flutter_jank_frame
flutter run --profile
```

## Profile in DevTools

1. Open Flutter DevTools and go to **Performance**.
2. Start recording.
3. Set compute toggle **OFF**.
4. Select `Not Optimized`, scroll fast, stop recording.
5. Reset stats, switch to `Optimized`, repeat same scroll motion.
6. Enable compute toggle **ON**, wait for precompute to finish.
7. Repeat steps 4-5 and compare timeline/missed-frame ratio.

## Suggested demo storyline

1. Worst case baseline: `Not Optimized` + compute OFF.
2. Structural optimization effect: `Optimized` + compute OFF.
3. Isolate offload effect: `Optimized` + compute ON.

## Notes

- In widget tests, `Image.network` does not fetch real network data; fallback visuals are expected.
- Prefer profile mode on a physical device for stable performance comparisons.
