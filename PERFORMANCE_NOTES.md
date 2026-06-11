# Performance Notes

> **Optimized for older multithreaded processors — because great UX shouldn't require the latest hardware.**

## 🎯 Target Hardware

ConsoleMac is tuned to run smoothly on:

- **Intel Macs (2015+)** with 4+ cores
- **Apple Silicon** (M1 and later) for best-in-class performance
- Systems with 8GB+ RAM (16GB recommended for local models)

## 🚀 What We Optimized

### Animation System

All animations use conservative timing curves optimized for lower frame budgets:

```swift
// Before: Generic ease-out
.animation(.easeOut(duration: 0.22), value: count)

// After: Tuned spring with higher damping for stability
.animation(Theme.Motion.entrance, value: count)
// → .spring(response: 0.35, dampingFraction: 0.75)
```

**Key changes:**
- Reduced ambient animation durations (1.6s → 1.2s)
- Increased damping on springs for fewer oscillations
- Shorter hover transitions (0.16s → 0.12s) to reduce GPU load
- Added `Theme.Motion.entrance` specifically for message list updates

### Memory Management

- Graceful state persistence failures prevent crashes under memory pressure
- MCP client cleanup handles pipe errors without crashing
- Model download tasks are properly cancelled on removal

### Concurrency

- All UI updates happen on `@MainActor`
- Background tasks (model downloads, API calls) run off the main thread
- Response streaming uses efficient token-by-token accumulation

## 📊 Benchmarks

| Action | Target FPS | Notes |
|--------|-----------|-------|
| Message scroll | 60fps | Uses lazy loading |
| Typing indicator | 30fps minimum | TimelineView-based |
| Sidebar navigation | 60fps | Pre-loaded thumbnails |
| Command palette open | 60fps | Spring animation |

## 🔧 Profiling Tips

To profile ConsoleMac:

```sh
# Build in release mode
swift build -c release

# Run with Instruments
open -a dist/Console.app
# Then use Activity Monitor or Xcode Instruments
```

Look for:
- Main thread blocking during streaming
- Unnecessary layout passes in message views
- Memory spikes during model downloads

## 💡 Contributing Performance Improvements

When submitting performance-related PRs:

1. **Test on Intel hardware** if possible
2. **Measure before/after** with concrete numbers
3. **Keep animations subtle** — flashiness ≠ quality
4. **Document trade-offs** in your commit message

---

*Performance is a feature. Every millisecond counts.* ❤️
