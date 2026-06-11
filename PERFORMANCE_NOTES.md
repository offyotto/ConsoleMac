# Performance Notes

Optimized for Intel Macs and older hardware.

## Target hardware

- Intel Macs (2015+) with 4+ cores
- Apple Silicon (M1+)
- 8GB+ RAM (16GB recommended for local models)

## Animation system

All animations use conservative timing curves:

```swift
// Before
.animation(.easeOut(duration: 0.22), value: count)

// After
.animation(Theme.Motion.entrance, value: count)
// .spring(response: 0.35, dampingFraction: 0.75)
```

Changes:
- Reduced ambient animation durations (1.6s → 1.2s)
- Increased spring damping for fewer oscillations
- Shorter hover transitions (0.16s → 0.12s)
- `Theme.Motion.entrance` for message list updates

## Memory

- Graceful state persistence failures prevent crashes under memory pressure
- MCP client cleanup handles pipe errors without crashing
- Model download tasks are cancelled on removal

## Concurrency

- All UI updates on `@MainActor`
- Background tasks (model downloads, API calls) off the main thread
- Response streaming uses token-by-token accumulation

## Benchmarks

| Action | Target | Notes |
|--------|--------|-------|
| Message scroll | 60fps | Lazy loading |
| Typing indicator | 30fps min | TimelineView-based |
| Sidebar navigation | 60fps | Pre-loaded |
| Command palette open | 60fps | Spring animation |

## Profiling

```sh
swift build -c release
open -a dist/Console.app
```

Watch for:
- Main thread blocking during streaming
- Unnecessary layout passes in message views
- Memory spikes during model downloads

## Submitting performance improvements

1. Test on Intel hardware if possible
2. Measure before and after
3. Keep animations subtle
4. Document trade-offs in the commit message
