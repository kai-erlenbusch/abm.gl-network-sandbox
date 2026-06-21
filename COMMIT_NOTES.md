# Commit Notes

### Refactoring & Bug Fixes
- **ChartGPU Memory Leak Resolution**: Fixed a severe memory leak and UI duplication glitch in the telemetry dashboard. The `<Chart>` component was previously double-mounting and spawning un-managed canvases due to a combination of React 18 Strict Mode behavior and unmounting async initialization within `chartgpu-react`.
  - **Solution**: Removed `key={setupTrigger}` to prevent chart unmounting. Bypassed the native `appendData` API (which suffered from un-clearable internal data caching) and implemented a custom manual data buffer via `useRef`. The chart is now cleanly wiped and fully refreshed using `setOption` replacements every frame.
- **Telemetry HUD Optimizations**: Rebuilt the simulation metrics header (Ticks, Time, FPS) to completely bypass the React rendering engine. 
  - **Solution**: Replaced React `useState` hooks with direct `useRef` DOM manipulation (`ref.current.innerText = ...`). This ensures that 60FPS updates are handled instantly without causing cascading virtual DOM diffs.
- **Physics Pause Synchronization**: The telemetry charting now correctly checks `useSimulationStore.getState().isPaused` before appending data. This prevents the chart from drifting or buffering while the physics simulation is halted.
- **Formatting**: Added HH:MM:SS simulation runtime clock based on a 60 ticks/second conversion, matching NetLogo style tick mechanics.

### Next Steps
- Implement advanced visual effects for the 2D graph (glow, link thickness based on infection, etc.) since 3D is architecturally incompatible with `@cosmos.gl/graph`.
- Expand controls for tuning initial graph topology (e.g. Watts-Strogatz vs Barabasi-Albert networks).
