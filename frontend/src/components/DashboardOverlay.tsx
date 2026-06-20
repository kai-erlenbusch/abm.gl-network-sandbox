'use client';
import { useEffect, useRef, useState } from 'react';
import { useSimulationStore } from '@/store/simulationStore';
import modelSchema from '../config/modelSchema.json';

function SliderWidget({ control }: { control: any }) {
  const globalValue = useSimulationStore(state => state.dynamicParams[control.id] ?? control.min);
  const setDynamicParam = useSimulationStore(state => state.setDynamicParam);
  
  const [localValue, setLocalValue] = useState(globalValue);

  useEffect(() => {
    setLocalValue(globalValue);
  }, [globalValue]);

  const commitValue = () => {
    setDynamicParam(control.id, localValue);
  };

  return (
    <div className="mb-3">
      <div className="flex justify-between items-center text-xs mb-1 text-neutral-400">
        <span>{control.label}</span>
        <input 
          type="number" 
          value={localValue} 
          min={control.min} 
          max={control.max} 
          step={control.step || 1}
          onChange={(e) => setLocalValue(parseFloat(e.target.value) || 0)}
          onBlur={commitValue}
          onKeyDown={(e) => e.key === 'Enter' && commitValue()}
          className="bg-neutral-800 text-right w-16 px-1 rounded border border-neutral-700 outline-none focus:border-emerald-500"
        />
      </div>
      <input 
        type="range" 
        min={control.min} 
        max={control.max} 
        step={control.step || 1}
        value={localValue}
        onChange={(e) => setLocalValue(parseFloat(e.target.value))}
        onPointerUp={commitValue}
        className="w-full h-1 bg-neutral-800 rounded-lg appearance-none cursor-pointer"
      />
    </div>
  );
}

function NumberWidget({ control }: { control: any }) {
  const value = useSimulationStore(state => state.dynamicParams[control.id] ?? control.default ?? 100000);
  const setDynamicParam = useSimulationStore(state => state.setDynamicParam);

  return (
    <div className="mb-3">
      <div className="flex justify-between items-center text-xs mb-1 text-neutral-400">
        <span>{control.label}</span>
        <input 
          type="number" 
          value={value} 
          min={control.min} 
          max={control.max} 
          step={control.step || 1}
          onChange={(e) => {
            const val = parseFloat(e.target.value);
            if (!isNaN(val)) {
               setDynamicParam(control.id, Math.max(control.min, Math.min(control.max, val)));
            }
          }}
          className="bg-neutral-800 text-right w-24 px-2 py-1 rounded border border-neutral-700 outline-none focus:border-emerald-500"
        />
      </div>
    </div>
  );
}

function ToggleWidget({ control }: { control: any }) {
  const isPaused = useSimulationStore(state => state.isPaused);
  const setIsPaused = useSimulationStore(state => state.setIsPaused);

  return (
    <button 
      onClick={() => setIsPaused(!isPaused)}
      className={`flex-1 py-2 rounded-lg text-xs font-bold transition-colors ${
        isPaused ? 'bg-amber-500/20 text-amber-500 hover:bg-amber-500/30' : 'bg-neutral-800 hover:bg-neutral-700'
      }`}
    >
      {isPaused ? `▶ ${control.label || 'RESUME'}` : `⏸ PAUSE`}
    </button>
  );
}

function SetupButtonWidget({ control }: { control: any }) {
  const triggerSetup = useSimulationStore(state => state.triggerSetup);
  return (
    <button 
      onClick={() => triggerSetup()}
      className="flex-1 py-2 rounded-lg text-xs font-bold transition-colors bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30 border border-emerald-500/30"
    >
      ↺ {control.label || 'SETUP'}
    </button>
  );
}

function FPSMeter() {
  const [fps, setFps] = useState(0);
  const frameCountRef = useRef(0);
  const lastFpsTimeRef = useRef(Date.now());

  useEffect(() => {
    const handleTelemetry = (e: any) => {
      frameCountRef.current++;
      const now = Date.now();
      if (now - lastFpsTimeRef.current >= 1000) {
        setFps(frameCountRef.current);
        frameCountRef.current = 0;
        lastFpsTimeRef.current = now;
      }
    };
    window.addEventListener('abm-frame', handleTelemetry);
    return () => window.removeEventListener('abm-frame', handleTelemetry);
  }, []);

  return (
    <div className="flex justify-between items-center mb-2">
      <div className="text-xs text-neutral-400">FPS: <span className="text-emerald-400 font-bold">{fps}</span></div>
    </div>
  );
}

function TelemetryChart() {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartInstanceRef = useRef<any>(null);
  const startTime = useRef(Date.now());
  const [resetKey, setResetKey] = useState(0);
  const agentCount = useSimulationStore(state => state.dynamicParams.agent_count);

  useEffect(() => {
    let isMounted = true;
    startTime.current = Date.now();
    
    async function initChart() {
      if (!containerRef.current) return;
      
      try {
        const { ChartGPU } = await import('chartgpu');
        const chart = await ChartGPU.create(containerRef.current, {
          series: [
            { 
              name: 'Food 1',
              type: 'line', 
              data: [], 
              sampling: 'none',
              // @ts-ignore
              style: { color: '#10b981', lineWidth: 2 } // emerald-500
            },
            { 
              name: 'Food 2',
              type: 'line', 
              data: [], 
              sampling: 'none',
              // @ts-ignore
              style: { color: '#ef4444', lineWidth: 2 } // red-500
            },
            { 
              name: 'Food 3',
              type: 'line', 
              data: [], 
              sampling: 'none',
              // @ts-ignore
              style: { color: '#3b82f6', lineWidth: 2 } // blue-500
            }
          ],
        });
        
        if (isMounted) {
          chartInstanceRef.current = chart;
        } else {
          if (chart && typeof chart.dispose === 'function') {
            chart.dispose();
          }
        }
      } catch (err) {
        console.warn("ChartGPU failed to initialize.", err);
      }
    }
    
    initChart();

    return () => {
      isMounted = false;
      if (chartInstanceRef.current && typeof chartInstanceRef.current.dispose === 'function') {
        chartInstanceRef.current.dispose();
      }
      chartInstanceRef.current = null;
    };
  }, [resetKey, agentCount]);

  useEffect(() => {
    const handleTelemetry = (e: any) => {
      if (!chartInstanceRef.current) return;
      
      const { food } = e.detail;
      const elapsed = (Date.now() - startTime.current) / 1000; // seconds

      const currentIsPaused = useSimulationStore.getState().isPaused;

      if (!currentIsPaused && food && typeof chartInstanceRef.current.appendData === 'function') {
        chartInstanceRef.current.appendData(0, [[elapsed, food[0] || 0]]);
        chartInstanceRef.current.appendData(1, [[elapsed, food[1] || 0]]);
        chartInstanceRef.current.appendData(2, [[elapsed, food[2] || 0]]);
      }
    };

    window.addEventListener('abm-telemetry', handleTelemetry);
    
    return () => {
      window.removeEventListener('abm-telemetry', handleTelemetry);
    };
  }, []);

  return (
    <div className="relative">
      <div className="absolute top-0 right-0 z-10 flex gap-2">
        <button 
           onClick={() => setResetKey(k => k + 1)}
           className="text-[10px] bg-neutral-800 hover:bg-neutral-700 text-neutral-400 px-2 py-0.5 rounded border border-neutral-700 transition-colors"
        >
           ↺ RESET
        </button>
      </div>
      <FPSMeter />
      <div ref={containerRef} className="w-full h-48 mt-2" />
    </div>
  );
}

function MetricsPanel() {
  const agentCount = useSimulationStore(state => state.dynamicParams.agent_count);
  const [metrics, setMetrics] = useState({ 
    ticks: 0, 
    transiting: 0, 
    totalDist: 0, 
    collectedFood: 0,
    collectionRate: 0 
  });
  const maxFoodRef = useRef(0);
  
  useEffect(() => {
    // Reset maxFood when agent count changes (usually means reset)
    maxFoodRef.current = 0;
  }, [agentCount]);

  useEffect(() => {
    let currentTicks = 0;
    const handleTicks = (e: any) => {
       currentTicks = e.detail.ticks;
       setMetrics(m => ({ ...m, ticks: currentTicks }));
    };
    
    const handleTelemetry = (e: any) => {
       const foodSum = (e.detail.food[0] || 0) + (e.detail.food[1] || 0) + (e.detail.food[2] || 0);
       // Track the maximum food seen (initial food)
       if (foodSum > maxFoodRef.current) maxFoodRef.current = foodSum;
       
       const collected = maxFoodRef.current - foodSum;
       // Assuming ~60 ticks per second, rate = collected / (ticks / 60)
       const rate = currentTicks > 0 ? (collected / (currentTicks / 60)) : 0;
       
       setMetrics(m => ({ 
         ...m, 
         transiting: e.detail.transiting, 
         totalDist: e.detail.totalDist,
         collectedFood: collected,
         collectionRate: rate
       }));
    };
    
    window.addEventListener('abm-ticks', handleTicks);
    window.addEventListener('abm-telemetry', handleTelemetry);
    return () => {
      window.removeEventListener('abm-ticks', handleTicks);
      window.removeEventListener('abm-telemetry', handleTelemetry);
    };
  }, []);

  return (
    <div className="grid grid-cols-2 gap-2 mb-4">
      <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
        <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Ant Count</div>
        <div className="text-sm font-bold text-neutral-200">{agentCount?.toLocaleString()}</div>
      </div>
      <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
        <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Time Elapsed</div>
        <div className="text-sm font-bold text-neutral-200">
          {Math.floor(metrics.ticks / 3600).toString().padStart(2, '0')}:
          {Math.floor((metrics.ticks / 60) % 60).toString().padStart(2, '0')}
        </div>
      </div>
      <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
        <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Transiting Food</div>
        <div className="text-sm font-bold text-emerald-400">{metrics.transiting.toLocaleString()}</div>
      </div>
      <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
        <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Collected Food</div>
        <div className="text-sm font-bold text-blue-400">{Math.floor(metrics.collectedFood).toLocaleString()}</div>
      </div>
      <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
        <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Collection Rate</div>
        <div className="text-sm font-bold text-neutral-200">{metrics.collectionRate.toFixed(1)} /s</div>
      </div>
      <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
        <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Total Distance</div>
        <div className="text-sm font-bold text-neutral-200">{Math.floor(metrics.totalDist).toLocaleString()}</div>
      </div>
    </div>
  );
}

export default function DashboardOverlay() {
  const isPaused = useSimulationStore(state => state.isPaused);
  const setIsPaused = useSimulationStore(state => state.setIsPaused);
  const [isCollapsed, setIsCollapsed] = useState(false);

  return (
    <>
      <style>{`
        .glass-scroll::-webkit-scrollbar {
          width: 6px;
        }
        .glass-scroll::-webkit-scrollbar-track {
          background: transparent;
        }
        .glass-scroll::-webkit-scrollbar-thumb {
          background: rgba(255, 255, 255, 0.1);
          border-radius: 10px;
        }
        .glass-scroll:hover::-webkit-scrollbar-thumb {
          background: rgba(255, 255, 255, 0.25);
        }
      `}</style>
      
      <div className={`absolute top-4 left-4 z-10 text-white font-mono text-sm bg-black/50 backdrop-blur-md rounded-xl border border-neutral-800 shadow-2xl pointer-events-auto transition-all duration-300 ease-in-out ${isCollapsed ? 'w-16 h-16 cursor-pointer flex items-center justify-center' : 'w-96 h-[95vh] p-6'}`}
           onClick={() => isCollapsed && setIsCollapsed(false)}>
        
        {isCollapsed ? (
          <div className="text-emerald-400 font-bold text-xl">≡</div>
        ) : (
          <div className="h-full w-full overflow-y-auto overflow-x-hidden glass-scroll pr-2">
            <div className="flex justify-between items-center mb-6">
              <div>
                <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-emerald-400">
                  abm.gl
                </h1>
                <p className="text-neutral-400 text-xs tracking-wider uppercase mt-1">Ant Simulation</p>
              </div>
              
              <div className="flex items-center space-x-3">
                <div className="flex items-center space-x-2">
                  <span className="relative flex h-3 w-3">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-3 w-3 bg-emerald-500"></span>
                  </span>
                  <span className="text-xs text-emerald-400">Live</span>
                </div>
                <button 
                  onClick={(e) => { e.stopPropagation(); setIsCollapsed(true); }}
                  className="text-neutral-400 hover:text-white transition-colors"
                  title="Collapse Sidebar"
                >
                  ✕
                </button>
              </div>
            </div>
      
      <div className="space-y-4">
        <div className="bg-neutral-900/50 p-4 rounded-lg border border-neutral-800">
          <div className="flex justify-between items-center text-xs mb-1 text-neutral-400">
            <span>Environment Map</span>
          </div>
          <select 
            className="w-full bg-neutral-800 text-neutral-200 text-xs rounded border border-neutral-700 px-2 py-1 outline-none focus:border-emerald-500 mt-1 mb-2"
            value={useSimulationStore((state) => state.mapType)}
            onChange={(e) => {
              useSimulationStore.getState().setMapType(e.target.value as any);
              useSimulationStore.getState().setIsPaused(true);
              useSimulationStore.getState().triggerSetup();
            }}
          >
            <option value="open">Open World</option>
            <option value="maze_1">Maze 1</option>
            <option value="maze_2">Maze 2</option>
            <option value="maze_3">Maze 3</option>
            <option value="maze_4">Maze 4</option>
            <option value="maze_5">Maze 5</option>
            <option value="maze_6">Maze 6</option>
            <option value="maze_7">Maze 7</option>
            <option value="maze_8">Maze 8</option>
          </select>

          <div className="flex items-center justify-between text-xs text-neutral-400 mt-2">
            <span>Visual Trails</span>
            <button
              onClick={() => useSimulationStore.getState().setVisualTrails(!useSimulationStore.getState().visualTrails)}
              className={`px-2 py-1 rounded transition-colors ${
                useSimulationStore.getState().visualTrails 
                  ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30' 
                  : 'bg-neutral-800 text-neutral-500 border border-neutral-700'
              }`}
            >
              {useSimulationStore.getState().visualTrails ? 'ON' : 'OFF'}
            </button>
          </div>
        </div>

        <div className="pt-4 border-t border-neutral-800">
          <h2 className="text-xs uppercase tracking-widest text-neutral-500 mb-2">Controls</h2>
          <div className="flex space-x-2 mb-4">
            {modelSchema.controls.filter((c: any) => c.type === 'button' || c.type === 'toggle').map((c: any) => {
              if (c.type === 'button') return <SetupButtonWidget key={c.id} control={c} />;
              if (c.type === 'toggle') return <ToggleWidget key={c.id} control={c} />;
              return null;
            })}
          </div>
          <div className="space-y-2">
            {modelSchema.controls.filter((c: any) => c.type === 'slider' || c.type === 'number').map((c: any) => {
              if (c.type === 'slider') return <SliderWidget key={c.id} control={c} />;
              if (c.type === 'number') return <NumberWidget key={c.id} control={c} />;
              return null;
            })}
          </div>
        </div>

        <div className="pt-4 border-t border-neutral-800">
          <h2 className="text-xs uppercase tracking-widest text-neutral-500 mb-2">Metrics</h2>
          <MetricsPanel />
        </div>

        <div className="pt-4 border-t border-neutral-800">
          <h2 className="text-xs uppercase tracking-widest text-neutral-500 mb-2">Real-time Telemetry (Food Piles)</h2>
          <TelemetryChart />
        </div>
      </div>
          </div>
        )}
      </div>
    </>
  );
}
