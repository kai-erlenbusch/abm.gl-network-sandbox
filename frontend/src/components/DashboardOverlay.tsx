'use client';
import { useEffect, useRef, useState } from 'react';
import { useSimulationStore } from '@/store/simulationStore';
import modelSchema from '../config/modelSchema.json';
import { ChartGPU as Chart, ChartInstance } from 'chartgpu-react';

function SliderWidget({ control }: { control: any }) {
  const globalValue = useSimulationStore((state: any) => state.dynamicParams[control.id] ?? control.min);
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
  const value = useSimulationStore((state: any) => state.dynamicParams[control.id] ?? control.default ?? 1000);
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
  const ticksRef = useRef<HTMLSpanElement>(null);
  const timeRef = useRef<HTMLSpanElement>(null);
  const localTicks = useRef(0);
  const setupTrigger = useSimulationStore(state => state.setupTrigger);

  useEffect(() => {
    localTicks.current = 0;
    if (ticksRef.current) ticksRef.current.innerText = "0";
    if (timeRef.current) timeRef.current.innerText = "00:00:00";
  }, [setupTrigger]);

  useEffect(() => {
    const handleRenderFrame = () => {
      frameCountRef.current++;
      const now = Date.now();
      if (now - lastFpsTimeRef.current >= 1000) {
        setFps(frameCountRef.current);
        frameCountRef.current = 0;
        lastFpsTimeRef.current = now;
      }
    };

    const handleTelemetry = (e: any) => {
      if (useSimulationStore.getState().isPaused) return;
      localTicks.current += (e.detail?.ticksToRun || 1);
      
      if (ticksRef.current) {
        ticksRef.current.innerText = localTicks.current.toString();
      }
      
      if (timeRef.current) {
        // Assume 60 ticks = 1 "second" or "hour" of simulation time. 
        // A simple HH:MM:SS format using 60 ticks = 1 in-game minute
        // or 1 in-game second. Let's do 60 ticks = 1 second.
        const totalSeconds = Math.floor(localTicks.current / 60);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        timeRef.current.innerText = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
      }
    };
    
    window.addEventListener('abm-render-frame', handleRenderFrame);
    window.addEventListener('abm-frame', handleTelemetry);
    return () => {
      window.removeEventListener('abm-render-frame', handleRenderFrame);
      window.removeEventListener('abm-frame', handleTelemetry);
    };
  }, []);

  return (
    <div className="flex justify-between items-center mb-2 bg-neutral-900/50 p-2 rounded-lg border border-neutral-800">
      <div className="text-xs text-neutral-400">TICKS: <span ref={ticksRef} className="text-blue-400 font-bold font-mono">0</span></div>
      <div className="text-xs text-neutral-400">TIME: <span ref={timeRef} className="text-blue-400 font-bold font-mono">00:00:00</span></div>
      <div className="text-xs text-neutral-400">FPS: <span className="text-amber-400 font-bold font-mono">{fps}</span></div>
    </div>
  );
}

export const initialChartOptions: any = {
  theme: 'dark',
  animation: false,
  xAxis: { type: 'linear' },
  yAxis: { type: 'linear' },
  grid: { top: 20, right: 20, bottom: 30, left: 40 },
  series: [
    { type: 'line', name: 'Susceptible', color: '#3b82f6', lineStyle: { width: 2 }, data: { x: [], y: [] } },
    { type: 'line', name: 'Resistant', color: '#6b7280', lineStyle: { width: 2 }, data: { x: [], y: [] } },
    { type: 'line', name: 'Infected', color: '#ef4444', lineStyle: { width: 2 }, data: { x: [], y: [] } },
  ]
};

function MetricsChart() {
  const chartRef = useRef<ChartInstance | null>(null);
  const timeRef = useRef(0);
  const dataRef = useRef<{x: number[], s: number[], r: number[], i: number[]}>({ x: [], s: [], r: [], i: [] });
  const setupTrigger = useSimulationStore(state => state.setupTrigger);

  useEffect(() => {
    timeRef.current = 0;
    dataRef.current = { x: [], s: [], r: [], i: [] };
    if (chartRef.current) {
      chartRef.current.setOption({
        ...initialChartOptions,
        series: [
          { ...initialChartOptions.series[0], data: { x: [], y: [] } },
          { ...initialChartOptions.series[1], data: { x: [], y: [] } },
          { ...initialChartOptions.series[2], data: { x: [], y: [] } },
        ]
      });
    }
  }, [setupTrigger]);

  useEffect(() => {
    const handleTelemetry = (e: any) => {
      if (useSimulationStore.getState().isPaused) return;
      if (e.detail && e.detail.food && chartRef.current) {
         const t = timeRef.current++;
         const s = e.detail.food[0];
         const i = e.detail.food[1];
         const r = e.detail.food[2];
         
         const data = dataRef.current;
         data.x.push(t);
         data.s.push(s);
         data.r.push(r);
         data.i.push(i);
         
         // Keep memory footprint lightweight
         if (data.x.length > 1000) {
           data.x.shift();
           data.s.shift();
           data.r.shift();
           data.i.shift();
         }
         
         chartRef.current.setOption({
            ...initialChartOptions,
            series: [
              { ...initialChartOptions.series[0], data: { x: [...data.x], y: [...data.s] } },
              { ...initialChartOptions.series[1], data: { x: [...data.x], y: [...data.r] } },
              { ...initialChartOptions.series[2], data: { x: [...data.x], y: [...data.i] } }
            ]
         });
      }
    };
    window.addEventListener('abm-frame', handleTelemetry);
    return () => window.removeEventListener('abm-frame', handleTelemetry);
  }, []);

  return (
    <div className="h-48 mt-2 bg-neutral-900/50 rounded-lg border border-neutral-800 relative p-1 pb-4 overflow-hidden">
      <Chart 
        onReady={(c) => { chartRef.current = c; }}
        options={initialChartOptions}
      />
    </div>
  );
}

function MetricsPanel() {
  const agentCount = useSimulationStore(state => state.dynamicParams.number_of_nodes);
  const [avgAssets, setAvgAssets] = useState("0");
  const [bankruptcies, setBankruptcies] = useState([0, 0, 0]);
  const [temperature, setTemperature] = useState(0);
  const [entropy, setEntropy] = useState(0);
  const [threatenedNodes, setThreatenedNodes] = useState(0);
  
  useEffect(() => {
    const handleTelemetry = (e: any) => {
      if (e.detail) {
          if (typeof e.detail.transiting !== 'undefined') setAvgAssets(e.detail.transiting.toFixed(0));
          if (e.detail.food) setBankruptcies(e.detail.food);
          if (typeof e.detail.temperature !== 'undefined') setTemperature(e.detail.temperature);
          if (typeof e.detail.entropy !== 'undefined') setEntropy(e.detail.entropy);
          if (typeof e.detail.threatenedNodes !== 'undefined') setThreatenedNodes(e.detail.threatenedNodes);
      }
    };
    window.addEventListener('abm-frame', handleTelemetry);
    return () => window.removeEventListener('abm-frame', handleTelemetry);
  }, []);

  const countSusceptible = bankruptcies[0] || 0;
  const countInfected = bankruptcies[1] || 0;
  const countResistant = bankruptcies[2] || 0;
  const total = countSusceptible + countInfected + countResistant;
  const pctSusceptible = total > 0 ? (countSusceptible / total) * 100 : 0;
  const pctInfected = total > 0 ? (countInfected / total) * 100 : 0;
  const pctResistant = total > 0 ? (countResistant / total) * 100 : 0;

  return (
    <div className="flex flex-col gap-2 mb-4">
      <div className="grid grid-cols-2 gap-2">
        <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
          <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Total Nodes</div>
          <div className="text-sm font-bold text-neutral-200">{agentCount?.toLocaleString()}</div>
        </div>
        <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800 text-center">
          <div className="text-[10px] text-neutral-500 uppercase tracking-wider">Infected</div>
          <div className="text-sm font-bold text-red-400">{countInfected.toLocaleString()}</div>
        </div>
      </div>
      <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800">
        <div className="text-[10px] text-neutral-500 uppercase tracking-wider mb-2 text-center">Network Status</div>
        <div className="flex h-3 w-full rounded-full overflow-hidden bg-neutral-800">
          <div style={{ width: `${pctSusceptible}%` }} className="bg-blue-500 transition-all duration-200"></div>
          <div style={{ width: `${pctResistant}%` }} className="bg-gray-500 transition-all duration-200"></div>
          <div style={{ width: `${pctInfected}%` }} className="bg-red-500 transition-all duration-200"></div>
        </div>
        <div className="flex justify-between mt-1 px-1">
          <span className="text-[9px] text-blue-400">{Math.round(pctSusceptible)}% Susceptible</span>
          <span className="text-[9px] text-gray-400">{Math.round(pctResistant)}% Resistant</span>
          <span className="text-[9px] text-red-400">{Math.round(pctInfected)}% Infected</span>
        </div>
        <MetricsChart />
      </div>
    </div>
  );
}

export default function DashboardOverlay() {
  const isPaused = useSimulationStore(state => state.isPaused);
  const setIsPaused = useSimulationStore(state => state.setIsPaused);
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);

  useEffect(() => {
    const handleGenStart = () => setIsGenerating(true);
    const handleGenEnd = () => setIsGenerating(false);
    window.addEventListener('abm-generating-start', handleGenStart);
    window.addEventListener('abm-generating-end', handleGenEnd);
    return () => {
      window.removeEventListener('abm-generating-start', handleGenStart);
      window.removeEventListener('abm-generating-end', handleGenEnd);
    };
  }, []);

  return (
    <>
      <style>{`
        .glass-scroll::-webkit-scrollbar { width: 6px; }
        .glass-scroll::-webkit-scrollbar-track { background: transparent; }
        .glass-scroll::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.1); border-radius: 10px; }
        .glass-scroll:hover::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.25); }
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
                <p className="text-neutral-400 text-xs tracking-wider uppercase mt-1">EPIDEMIC VIRUS</p>
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
                >
                  ✕
                </button>
              </div>
            </div>
      
            <div className="space-y-4">
              <FPSMeter />
              <MetricsPanel />
              
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
                <h2 className="text-xs uppercase tracking-widest text-neutral-500 mb-2">Configuration</h2>
                <div className="bg-neutral-900/50 p-2 rounded-lg border border-neutral-800">
                   <div className="text-[10px] text-neutral-400 uppercase tracking-wider mb-1">Architecture</div>
                   <div className="text-sm font-bold text-blue-400">WebGPU + cosmos.gl (Raw)</div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {isGenerating && (
        <div className="absolute inset-0 z-50 flex flex-col items-center justify-center bg-black/60 backdrop-blur-sm pointer-events-auto">
          <div className="w-16 h-16 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin mb-4"></div>
          <h2 className="text-white text-xl font-mono font-bold tracking-widest">GENERATING NETWORK...</h2>
        </div>
      )}
    </>
  );
}
