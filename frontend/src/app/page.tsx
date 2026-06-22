'use client';
import dynamic from 'next/dynamic';
import DashboardOverlay from '@/components/DashboardOverlay';
import { useSimulationStore } from '@/store/simulationStore';
import { useMemo, useEffect, useRef, useState, useCallback } from 'react';
import { VirusDynamicsEngine, MAX_NODES } from '@/engine/physics/VirusDynamics';
import { Graph } from '@cosmos.gl/graph';

type VirusNode = {
    id: string;
    index: number;
    state: number; // 0=Susceptible, 1=Infected, 2=Resistant
    timer: number;
    x: number;
    y: number;
};

const AbmCompute = dynamic(() => import('@/components/AbmCanvas'), {
  ssr: false,
  loading: () => null
});

async function generateSpatiallyClusteredNetwork(n: number, avgDegree: number, initialOutbreakSize: number) {
    const densityArea = 2000; // slightly more area per node to allow spread between clusters
    const totalArea = n * densityArea;
    const worldRadius = Math.sqrt(totalArea / Math.PI);
    
    // Create Hubs (City centers)
    const numHubs = Math.max(1, Math.floor(n / 400));
    const hubs = Array.from({ length: numHubs }, () => {
        const r = worldRadius * Math.sqrt(Math.random());
        const theta = Math.random() * 2 * Math.PI;
        return { x: r * Math.cos(theta), y: r * Math.sin(theta) };
    });
    
    const hubSpread = Math.sqrt(totalArea / numHubs / Math.PI) * 0.8; // standard deviation for node placement
    const hubNodes: number[][] = Array.from({length: numHubs}, () => []);

    const nodes = Array.from({ length: n }, (_, i) => {
        const hubIndex = Math.floor(Math.random() * numHubs);
        const c = hubs[hubIndex];
        
        // Box-Muller transform for normal distribution
        let u = 0, v = 0;
        while(u === 0) u = Math.random();
        while(v === 0) v = Math.random();
        const z0 = Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
        const z1 = Math.sqrt(-2.0 * Math.log(u)) * Math.sin(2.0 * Math.PI * v);
        
        hubNodes[hubIndex].push(i);
        
        return { 
            id: i.toString(), 
            index: i, 
            state: 0,
            timer: Math.floor(Math.random() * 100),
            x: c.x + z0 * hubSpread,
            y: c.y + z1 * hubSpread,
            hub: hubIndex
        };
    });

    const links: { source: string, target: string, sourceIndex: number, targetIndex: number }[] = [];
    const targetLinks = Math.floor((avgDegree * n) / 2);
    const adjacency: number[][] = Array.from({ length: n }, () => []);
    const adjacencySets: Set<number>[] = Array.from({ length: n }, () => new Set());
    const dist = (n1: any, n2: any) => Math.sqrt((n1.x - n2.x)**2 + (n1.y - n2.y)**2);

    let failedAttempts = 0;
    let linksGenerated = 0;
    
    while (links.length < targetLinks && failedAttempts < 2000) {
        if (++linksGenerated % 1000 === 0) {
            await new Promise(r => setTimeout(r, 0)); // Yield to keep UI responsive
        }
        
        const n1Index = Math.floor(Math.random() * n);
        const n1 = nodes[n1Index];
        
        let closestNodeIndex = -1;
        let minDistance = Infinity;
        
        // 85% chance to build local community edges, 15% chance to build global highway edges
        const intraHubSearch = Math.random() < 0.85;
        const k = Math.min(n - 1, 40);
        
        for (let i = 0; i < k; i++) {
            let candidateIndex = -1;
            if (intraHubSearch && hubNodes[n1.hub].length > 1) {
                const hlist = hubNodes[n1.hub];
                candidateIndex = hlist[Math.floor(Math.random() * hlist.length)];
            } else {
                candidateIndex = Math.floor(Math.random() * n);
            }
            
            if (candidateIndex === n1Index) continue;
            if (adjacencySets[n1Index].has(candidateIndex)) continue;
            
            const d = dist(n1, nodes[candidateIndex]);
            if (d < minDistance) {
                minDistance = d;
                closestNodeIndex = candidateIndex;
            }
        }
        
        if (closestNodeIndex !== -1 && minDistance < 100000) {
            links.push({
                source: n1Index.toString(),
                target: closestNodeIndex.toString(),
                sourceIndex: n1Index,
                targetIndex: closestNodeIndex
            });
            adjacency[n1Index].push(closestNodeIndex);
            adjacency[closestNodeIndex].push(n1Index);
            adjacencySets[n1Index].add(closestNodeIndex);
            adjacencySets[closestNodeIndex].add(n1Index);
            failedAttempts = 0;
        } else {
            failedAttempts++;
        }
    }
    
    for (let i = 0; i < initialOutbreakSize; i++) {
        let r = Math.floor(Math.random() * n);
        while(nodes[r].state === 1) {
            r = Math.floor(Math.random() * n);
        }
        nodes[r].state = 1;
    }
    
    return { nodes, links, adjacency };
}

export default function Home() {
  const agentCount = useSimulationStore(state => state.dynamicParams.number_of_nodes ?? 150);
  const avgDegree = useSimulationStore(state => state.dynamicParams.average_node_degree ?? 6);
  const initialOutbreakSize = useSimulationStore(state => state.dynamicParams.initial_outbreak_size ?? 3);
  const setupTrigger = useSimulationStore(state => state.setupTrigger);
  
  const [network, setNetwork] = useState<{ nodes: any[], links: any[], adjacency: number[][] }>({ nodes: [], links: [], adjacency: [] });
  const [debugLogs, setDebugLogs] = useState<string[]>([]);

  const log = useCallback((msg: string) => {
      setDebugLogs(prev => [...prev.slice(-9), msg]);
  }, []);
  
  const divRef = useRef<HTMLDivElement>(null);
  const engineRef = useRef<any>(null);
  const graphRef = useRef<any>(null);
  const readbackPendingRef = useRef(false);
  const colorArrayRef = useRef<Float32Array | null>(null);

  useEffect(() => {
    if (!divRef.current) return;
    log("Graph init started");
    const config = {
      backgroundColor: '#0a0a0a',
      spaceSize: 8192,
      fitViewOnInit: true,
      fitViewPadding: 0.1,
      simulation: false
    };

    try {
        // @ts-ignore
        const graph = new Graph(divRef.current, config);
        graphRef.current = graph;
        log("Graph init successful");

        return () => {
          log("Graph destroyed");
          graph.destroy();
        };
    } catch (e: any) {
        log("Graph error: " + e.message);
    }
  }, []);

  const [engineData, setEngineData] = useState<{engine: any, setupPass: any, passes: any[]}>({engine: null, setupPass: null, passes: []});

  useEffect(() => {
     let mounted = true;
     const buildSimulation = async () => {
         window.dispatchEvent(new CustomEvent('abm-generating-start'));
         
         const n = Math.min(agentCount, MAX_NODES);
         
         // 1. Generate the network (already chunked internally)
         log("Generating network...");
         const { nodes, links, adjacency } = await generateSpatiallyClusteredNetwork(n, avgDegree, initialOutbreakSize);
         if (!mounted) return;
         
         setNetwork({ nodes, links, adjacency });
         
         // 2. Prepare Cosmos.gl data arrays async
         log(`Network generated: ${n} nodes. Updating Graph...`);
         if (graphRef.current) {
             const graph = graphRef.current;
             try {
                 const positions = new Float32Array(n * 2);
                 for (let i = 0; i < n; i++) {
                     positions[i*2] = nodes[i].x;
                     positions[i*2+1] = nodes[i].y;
                 }
                 graph.setPointPositions(positions);

                 // Dynamically scale point size so large networks don't become solid blobs
                 const baseSize = n > 10000 ? 3.5 : (n > 5000 ? 4.5 : 6.0);
                 const sizes = new Float32Array(n).fill(baseSize);
                 graph.setPointSizes(sizes);
                 
                 const linksArray = new Float32Array(links.length * 2);
                 for (let i = 0; i < links.length; i++) {
                     linksArray[i*2] = links[i].sourceIndex;
                     linksArray[i*2+1] = links[i].targetIndex;
                 }
                 graph.setLinks(linksArray);
                 graph.pause();

                 const colors = new Float32Array(n * 4);
                 let inf = 0; let res = 0; let sus = 0;
                 
                 const chunkSize = 20000;
                 for (let i = 0; i < n; i += chunkSize) {
                     const end = Math.min(i + chunkSize, n);
                     for (let j = i; j < end; j++) {
                         const state = nodes[j].state;
                         if (state === 1) inf++;
                         else if (state === 2) res++;
                         else sus++;
                         
                         colors[j*4] = state === 1 ? 1.0 : (state === 2 ? 0.5 : 0.2); // r
                         colors[j*4+1] = state === 1 ? 0.2 : (state === 2 ? 0.5 : 0.6); // g
                         colors[j*4+2] = state === 1 ? 0.2 : (state === 2 ? 0.5 : 1.0); // b
                         colors[j*4+3] = 1.0; // a
                     }
                     if (end < n) await new Promise(r => setTimeout(r, 0));
                     if (!mounted) return;
                 }
                 
                 console.log(`[abm-gl] initial state: N=${n}, sus=${sus}, inf=${inf}, res=${res}`);
                 graph.setPointColors(colors);
                 
                 log(`Graph data applied. Rendering...`);
                 setTimeout(() => {
                     if (graphRef.current && mounted) {
                         graphRef.current.setZoomTransformByPointPositions(positions, 0, undefined, 0.1, false);
                         graphRef.current.render();
                         log(`Graph render complete`);
                     }
                 }, 100);
             } catch (e: any) {
                 log(`Graph data error: ` + e.message);
             }
         }
         
         // 3. Build WebGPU Engine async
         const totalEdges = adjacency.reduce((sum, adj) => sum + adj.length, 0);
         const engine = new VirusDynamicsEngine(n, totalEdges);
         console.log("Creating VirusDynamics engine with", n, "agents and", totalEdges, "edges.");
         
         const stateBufferRead = engine.stateBufferRead.value.array as Float32Array;
         const stateBufferWrite = engine.stateBufferWrite.value.array as Float32Array;
         const neighborCounts = engine.neighborCounts.value.array as Uint32Array;
         const neighborStartIndices = engine.neighborStartIndices.value.array as Uint32Array;
         const neighborDestinations = engine.neighborDestinations.value.array as Uint32Array;
         
         let currentEdgeIdx = 0;
         let infectedCount = 0;
         
         const engineChunkSize = 10000;
         for (let i = 0; i < n; i += engineChunkSize) {
             const end = Math.min(i + engineChunkSize, n);
             for (let j = i; j < end; j++) {
                 const node = nodes[j];
                 if (node.state === 1) infectedCount++;
                 
                 stateBufferRead[j * 4] = node.state;
                 stateBufferRead[j * 4 + 1] = node.timer;
                 stateBufferRead[j * 4 + 2] = 0.0;
                 
                 stateBufferWrite[j * 4] = node.state;
                 stateBufferWrite[j * 4 + 1] = node.timer;
                 stateBufferWrite[j * 4 + 2] = 0.0;
                 
                 const neighbors = adjacency[j];
                 neighborCounts[j] = neighbors.length;
                 neighborStartIndices[j] = currentEdgeIdx;
                 for (let k = 0; k < neighbors.length; k++) {
                     neighborDestinations[currentEdgeIdx++] = neighbors[k];
                 }
             }
             if (end < n) await new Promise(r => setTimeout(r, 0));
             if (!mounted) return;
         }
         
         console.log("Engine init: nodes " + n + " infected " + infectedCount);
         
         engine.stateBufferRead.value.needsUpdate = true;
         engine.stateBufferWrite.value.needsUpdate = true;
         engine.neighborCounts.value.needsUpdate = true;
         engine.neighborStartIndices.value.needsUpdate = true;
         engine.neighborDestinations.value.needsUpdate = true;
         
         engineRef.current = engine;
         setEngineData({ engine, setupPass: engine.setupPass, passes: [engine.simulationPass, engine.copyPass] });
         
         window.dispatchEvent(new CustomEvent('abm-generating-end'));
         window.dispatchEvent(new CustomEvent('abm-ticks', { detail: { ticks: 0 } }));
     };
     
     buildSimulation();
     return () => { mounted = false; };
  }, [setupTrigger, agentCount, avgDegree, initialOutbreakSize]);
  
  const { engine, setupPass, passes } = engineData;


  const { virus_spread_chance, virus_check_frequency, recovery_chance, gain_resistance_chance } = useSimulationStore(state => state.dynamicParams);
  
  const [globalError, setGlobalError] = useState<string | null>(null);

  useEffect(() => {
    const handleRejection = (event: PromiseRejectionEvent) => {
        console.error("Unhandled promise rejection:", event.reason);
        setGlobalError(String(event.reason?.stack || event.reason || "Unknown promise rejection"));
    };
    const handleError = (event: ErrorEvent) => {
        console.error("Global error:", event.error);
        setGlobalError(String(event.error?.stack || event.error || "Unknown global error"));
    };
    window.addEventListener('unhandledrejection', handleRejection);
    window.addEventListener('error', handleError);
    return () => {
        window.removeEventListener('unhandledrejection', handleRejection);
        window.removeEventListener('error', handleError);
    };
  }, []);

  const updateUniforms = useCallback(() => {
      if (!engineRef.current) return;
      const engine = engineRef.current;
      engine.uniforms.virusSpreadChance.value = (virus_spread_chance ?? 2.5) / 100.0;
      engine.uniforms.virusCheckFrequency.value = virus_check_frequency ?? 1.0;
      engine.uniforms.recoveryChance.value = (recovery_chance ?? 5.0) / 100.0;
      engine.uniforms.gainResistanceChance.value = (gain_resistance_chance ?? 5.0) / 100.0;
      engine.uniforms.randomSeed.value = Math.random();
  }, [virus_spread_chance, virus_check_frequency, recovery_chance, gain_resistance_chance]);

  const renderCallback = useCallback(async (gl: any, delta: number, ticksToRun: number, activeEngine: any) => {
      if (!activeEngine) {
          log("renderCallback missing engine");
          return;
      }
      const engine = activeEngine;
      if (!graphRef.current) {
          log("renderCallback missing graph");
          return;
      }
      
      if (ticksToRun === 0) {
          // Only report telemetry from CPU state to avoid wiping out the initial state before GPU is fully primed
          const N = network.nodes.length;
          let countSusceptible = 0;
          let countInfected = 0;
          let countResistant = 0;
          
          if (!colorArrayRef.current || colorArrayRef.current.length !== N * 4) {
              colorArrayRef.current = new Float32Array(N * 4);
          }
          const colorArr = colorArrayRef.current;
          
          for(let i = 0; i < N; i++) {
              const state = network.nodes[i].state;
                if (state === 0) {
                    countSusceptible++;
                    colorArr[i*4] = 0.23; colorArr[i*4+1] = 0.51; colorArr[i*4+2] = 0.96; colorArr[i*4+3] = 1.0;
                } else if (state === 1) {
                    countInfected++;
                    colorArr[i*4] = 0.93; colorArr[i*4+1] = 0.26; colorArr[i*4+2] = 0.26; colorArr[i*4+3] = 1.0;
                } else if (state === 2) {
                    countResistant++;
                    colorArr[i*4] = 0.45; colorArr[i*4+1] = 0.45; colorArr[i*4+2] = 0.45; colorArr[i*4+3] = 1.0;
                }
          }
          
          window.dispatchEvent(new CustomEvent('abm-frame', { 
                detail: { 
                    food: [countSusceptible, countInfected, countResistant],
                    total: N,
                    ticksToRun: 0
                } 
            }));
          
          if (graphRef.current) {
              graphRef.current.setPointColors(colorArr);
          }
          return;
      }

      if (readbackPendingRef.current) return;
      if (ticksToRun === 0) {
          // If no ticks ran, the GPU buffers might not be fully bound yet or state hasn't changed.
          // The visual state is already correct from the initial CPU setup.
          window.dispatchEvent(new CustomEvent('abm-frame', {
              detail: { 
                  food: [network.nodes.length, 0, 0], // simplified
                  ticksToRun: 0
              }
          }));
          return;
      }
      readbackPendingRef.current = true;

      try {
        // Request WebGPU to transfer the buffer from GPU to CPU
          const readAttr = engine.stateBufferWrite.bufferNode ? engine.stateBufferWrite.bufferNode.value : engine.stateBufferWrite.value;
          
          if (!readAttr || (!readAttr.isStorageBufferAttribute && !readAttr.isStorageInstancedBufferAttribute)) {
              console.warn("readAttr is not a valid Storage Attribute yet", readAttr);
          }

          // Request WebGPU to transfer the buffer from GPU to CPU
          const stateBuffer = await gl.getArrayBufferAsync(readAttr);
          
          if (!stateBuffer) {
              console.error("[page.tsx] Received null/undefined buffer from readback");
              return;
          }
          
          const graph = graphRef.current;
          const N = network.nodes.length;
          let countSusceptible = 0;
          let countInfected = 0;
          let countResistant = 0;
          
          const stateArr = new Float32Array(stateBuffer);
          
          if (stateArr.length === 0) {
              console.error("stateArr is EMPTY!");
          }
          
          // Debug first few agents' totalTicks to verify compute shader execution
          let totalTicksSum = 0;
          for (let k = 0; k < Math.min(N, 10); k++) {
              totalTicksSum += stateArr[k * 4 + 2];
          }
          if (typeof document !== 'undefined') {
              document.title = "Ticks: " + totalTicksSum;
          }
          if (totalTicksSum === 0) {
              console.warn(`[page.tsx] GPU Compute pass might not be executing! totalTicks is 0 for first 10 agents.`);
          }
      
      if (!colorArrayRef.current || colorArrayRef.current.length !== N * 4) {
                colorArrayRef.current = new Float32Array(N * 4);
            }
            const colorArr = colorArrayRef.current;
            
            for(let i = 0; i < N; i++) {
                const state = Math.round(stateArr[i * 4]);
                network.nodes[i].state = state;
                  
                  if (state === 0) {
                      countSusceptible++;
                      colorArr[i*4] = 0.23; colorArr[i*4+1] = 0.51; colorArr[i*4+2] = 0.96; colorArr[i*4+3] = 1.0;
                  }
                  else if (state === 1) {
                      countInfected++;
                      colorArr[i*4] = 0.93; colorArr[i*4+1] = 0.26; colorArr[i*4+2] = 0.26; colorArr[i*4+3] = 1.0;
                  }
                  else if (state === 2) {
                      countResistant++;
                      colorArr[i*4] = 0.45; colorArr[i*4+1] = 0.45; colorArr[i*4+2] = 0.45; colorArr[i*4+3] = 1.0;
                  }
              }
              
              graph.setPointColors(colorArr);
              graph.render();
              
              window.dispatchEvent(new CustomEvent('abm-frame', {
                  detail: { 
                      food: [countSusceptible, countInfected, countResistant],
                      ticksToRun
                  }
              }));

          } catch (e) {
              console.warn("Readback error", e);
          } finally {
              readbackPendingRef.current = false;
          }
  }, [network]);

  return (
  <main className="relative w-full h-screen overflow-hidden bg-[#0a0a0a]">
      {globalError && (
          <div className="absolute top-0 left-0 w-full z-50 bg-red-900/90 text-white p-4 font-mono text-xs whitespace-pre-wrap max-h-[50vh] overflow-y-auto">
              <h3 className="text-red-300 font-bold mb-2">CRITICAL ERROR</h3>
              {globalError}
          </div>
      )}
      <div className="absolute inset-0 z-0">
        <div 
            ref={divRef} 
            className="w-full h-full"
        />
    </div>

    <AbmCompute 
        engine={engine}
        setupPass={setupPass} 
        computePasses={passes}
        renderCallback={renderCallback}
        updateUniforms={updateUniforms}
    />

    <div className="absolute inset-0 z-10 pointer-events-none">
      <DashboardOverlay />
    </div>

    <div className="absolute top-4 right-4 z-50 bg-black/80 text-green-400 p-4 font-mono text-xs max-w-sm rounded border border-green-500/30 overflow-hidden pointer-events-none">
        <h3 className="text-white mb-2 font-bold uppercase">System Logs</h3>
        {debugLogs.map((m, i) => <div key={i}>&gt; {m}</div>)}
    </div>
  </main>
);
}
