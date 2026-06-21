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
  const nodes = Array.from({ length: n }, (_, i) => ({ 
      id: i.toString(), 
      index: i, 
      state: 0,
      timer: Math.floor(Math.random() * 100),
      x: Math.random() * 1000 - 500,
      y: Math.random() * 1000 - 500
  }));
  const links: { source: string, target: string, sourceIndex: number, targetIndex: number }[] = [];
  
  const targetLinks = Math.floor((avgDegree * n) / 2);
  const adjacency: number[][] = Array.from({ length: n }, () => []);
  const adjacencySets: Set<number>[] = Array.from({ length: n }, () => new Set());

  const dist = (n1: VirusNode, n2: VirusNode) => Math.sqrt((n1.x - n2.x)**2 + (n1.y - n2.y)**2);

    let failedAttempts = 0;
    let linksGenerated = 0;
    while (links.length < targetLinks && failedAttempts < 1000) {
        if (++linksGenerated % 1000 === 0) {
            await new Promise(r => setTimeout(r, 0)); // Yield to keep UI responsive
        }
        
        const n1Index = Math.floor(Math.random() * n);
        const n1 = nodes[n1Index];
        
        let closestNodeIndex = -1;
        let minDistance = Infinity;
        for (let i = 0; i < n; i++) {
            if (i === n1Index) continue;
            if (adjacencySets[n1Index].has(i)) continue;
            
            const d = dist(n1, nodes[i]);
            if (d < minDistance) {
                minDistance = d;
                closestNodeIndex = i;
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
    
    // Apply a simple spring layout for 50 iterations to make it look like NetLogo
    if (n <= 5000) {
        for (let iter = 0; iter < 50; iter++) {
            await new Promise(r => setTimeout(r, 0)); // Yield to main thread every iteration
          const forces = Array.from({ length: n }, () => ({ x: 0, y: 0 }));
          
          // Repulsion
          for (let i = 0; i < n; i++) {
              for (let j = i + 1; j < n; j++) {
                  const dx = nodes[i].x - nodes[j].x;
                  const dy = nodes[i].y - nodes[j].y;
                  let d2 = dx*dx + dy*dy;
                  if (d2 === 0) d2 = 0.1;
                  if (d2 < 25000) { 
                      const d = Math.sqrt(d2);
                      const force = 150 / d; 
                      forces[i].x += (dx / d) * force;
                      forces[i].y += (dy / d) * force;
                      forces[j].x -= (dx / d) * force;
                      forces[j].y -= (dy / d) * force;
                  }
              }
          }
          
          // Springs
          for (const link of links) {
              const n1 = nodes[link.sourceIndex];
              const n2 = nodes[link.targetIndex];
              const dx = n2.x - n1.x;
              const dy = n2.y - n1.y;
              const d = Math.sqrt(dx*dx + dy*dy) || 0.1;
              
              const force = (d - 30) * 0.1; 
              forces[link.sourceIndex].x += (dx / d) * force;
              forces[link.sourceIndex].y += (dy / d) * force;
              forces[link.targetIndex].x -= (dx / d) * force;
              forces[link.targetIndex].y -= (dy / d) * force;
          }
          
          // Apply forces
          for (let i = 0; i < n; i++) {
              nodes[i].x += Math.max(-50, Math.min(50, forces[i].x || 0));
              nodes[i].y += Math.max(-50, Math.min(50, forces[i].y || 0));
              // Gravity towards center
              nodes[i].x -= nodes[i].x * 0.05;
              nodes[i].y -= nodes[i].y * 0.05;
          }
      }
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
  const readbackPendingRef = useRef(false);
  const colorArrayRef = useRef<Float32Array | null>(null);
  const graphRef = useRef<Graph | null>(null);

  useEffect(() => {
    if (!divRef.current) return;
    log("Graph init started");
    const config = {
      backgroundColor: '#0a0a0a',
      spaceSize: 8192,
      fitViewOnInit: false,
      fitViewPadding: 0.1,
      simulation: false,
      simulationGravity: 0.05,
      simulationRepulsion: 0.5,
      simulationFriction: 0.8,
      simulationLinkDistance: 15,
      simulationLinkSpring: 0.2
    };

    try {
        // @ts-ignore
        const graph = new Graph(divRef.current, config);
        graph.pause();
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

  useEffect(() => {
    const N = network.nodes.length;
    log(`Network updated: ${N} nodes. Graph: ${!!graphRef.current}`);
    if (!graphRef.current || network.nodes.length === 0) return;
    const graph = graphRef.current;
    
    try {
        const positions = new Float32Array(N * 2);
        for (let i = 0; i < N; i++) {
            positions[i*2] = network.nodes[i].x;
            positions[i*2+1] = network.nodes[i].y;
        }
        graph.setPointPositions(positions);

        const sizes = new Float32Array(N).fill(5.0); // Make them bigger to see
        graph.setPointSizes(sizes);
        
        const linksArray = new Float32Array(network.links.length * 2);
        for (let i = 0; i < network.links.length; i++) {
            linksArray[i*2] = network.links[i].sourceIndex;
            linksArray[i*2+1] = network.links[i].targetIndex;
        }
        graph.setLinks(linksArray);
        graph.pause();

        const colors = new Float32Array(N * 4);
        for (let i = 0; i < N; i++) {
            colors[i*4] = 0.2; // r
            colors[i*4+1] = 0.6; // g
            colors[i*4+2] = 1.0; // b
            colors[i*4+3] = 1.0; // a
        }
        graph.setPointColors(colors);
        
        log(`Graph data applied. Rendering...`);
        // In Cosmos.gl v3, fitViewOnInit might not trigger perfectly if the simulation is disabled and device is async
        setTimeout(() => {
            if (graphRef.current) {
                graphRef.current.setZoomTransformByPointPositions(positions, 0, undefined, 0.1, false);
                graphRef.current.render();
                log(`Graph render complete`);
            }
        }, 100);
    } catch (e: any) {
        log(`Graph data error: ` + e.message);
    }
  }, [network]);

  useEffect(() => {
     let mounted = true;
     const n = Math.min(agentCount, MAX_NODES);
     
     const buildNetwork = async () => {
         window.dispatchEvent(new CustomEvent('abm-generating-start'));
         const { nodes, links, adjacency } = await generateSpatiallyClusteredNetwork(n, avgDegree, initialOutbreakSize);
         if (!mounted) return;
         setNetwork({ nodes, links, adjacency });
         window.dispatchEvent(new CustomEvent('abm-generating-end'));
         window.dispatchEvent(new CustomEvent('abm-ticks', { detail: { ticks: 0 } }));
     };
     
     buildNetwork();
     return () => { mounted = false; };
  }, [setupTrigger, agentCount, avgDegree, initialOutbreakSize]);
  
  const { engine, setupPass, passes } = useMemo(() => {
      if (network.nodes.length === 0) return { engine: null, setupPass: null, passes: [] };
      
      const n = network.nodes.length;
      
      let totalEdges = 0;
      for (let i = 0; i < n; i++) totalEdges += network.adjacency[i].length;
      
      const engine = new VirusDynamicsEngine(n, totalEdges);
      
      const stateBufferRead = engine.stateBufferRead.value.array as Float32Array;
      const stateBufferWrite = engine.stateBufferWrite.value.array as Float32Array;
      
      const neighborCounts = engine.neighborCounts.value.array as Uint32Array;
      const neighborStartIndices = engine.neighborStartIndices.value.array as Uint32Array;
      const neighborDestinations = engine.neighborDestinations.value.array as Uint32Array;
      
      let currentEdgeIdx = 0;
      let infectedCount = 0;
      for (let i = 0; i < n; i++) {
          const node = network.nodes[i];
          if (node.state === 1) infectedCount++;
          
          stateBufferRead[i * 4] = node.state;
          stateBufferRead[i * 4 + 1] = node.timer;
          
          stateBufferWrite[i * 4] = node.state;
          stateBufferWrite[i * 4 + 1] = node.timer;
          
          const neighbors = network.adjacency[i];
          neighborCounts[i] = neighbors.length;
          neighborStartIndices[i] = currentEdgeIdx;
          for (let j = 0; j < neighbors.length; j++) {
             neighborDestinations[currentEdgeIdx++] = neighbors[j];
          }
      }
      log("Engine init: nodes " + n + " infected " + infectedCount);
      
      engine.stateBufferRead.value.needsUpdate = true;
      engine.stateBufferWrite.value.needsUpdate = true;
      engine.neighborCounts.value.needsUpdate = true;
      engine.neighborStartIndices.value.needsUpdate = true;
      engine.neighborDestinations.value.needsUpdate = true;
      
      engineRef.current = engine;
      return { engine, setupPass: engine.setupPass, passes: [engine.simulationPass, engine.copyPass] };
  }, [network.adjacency]);

  const { virus_spread_chance, virus_check_frequency, recovery_chance, gain_resistance_chance } = useSimulationStore(state => state.dynamicParams);
  
  const updateUniforms = useCallback(() => {
      if (!engineRef.current) return;
      const engine = engineRef.current;
      engine.uniforms.virusSpreadChance.value = (virus_spread_chance ?? 2.5) / 100.0;
      engine.uniforms.virusCheckFrequency.value = virus_check_frequency ?? 1.0;
      engine.uniforms.recoveryChance.value = (recovery_chance ?? 5.0) / 100.0;
      engine.uniforms.gainResistanceChance.value = (gain_resistance_chance ?? 5.0) / 100.0;
      engine.uniforms.randomSeed.value = Math.random();
  }, [virus_spread_chance, virus_check_frequency, recovery_chance, gain_resistance_chance]);

    const lastUpdateRef = useRef(0);
    const lastLogRef = useRef(0);

    const renderCallback = useCallback(async (gl: any, delta: number, ticksToRun: number) => {
        if (!engine) {
            if (!readbackPendingRef.current) {
                readbackPendingRef.current = true;
                log("renderCallback missing engine");
            }
            return;
        }
        if (!graphRef.current) {
            if (!readbackPendingRef.current) {
                readbackPendingRef.current = true;
                log("renderCallback missing graph");
            }
            return;
        }
        
        if (ticksToRun === 0) {
            // Only report telemetry from CPU state to avoid wiping out the initial state before GPU is fully primed
            const N = network.nodes.length;
            let countSusceptible = 0;
            let countInfected = 0;
            let countResistant = 0;
            
            for(let i = 0; i < N; i++) {
                const state = network.nodes[i].state;
                if (state === 0) countSusceptible++;
                else if (state === 1) countInfected++;
                else if (state === 2) countResistant++;
            }
            
            window.dispatchEvent(new CustomEvent('abm-telemetry', { 
                detail: { 
                    susceptible: countSusceptible,
                    infected: countInfected,
                    resistant: countResistant,
                    total: N,
                    ticksToRun: 0
                } 
            }));
            return;
        }

        if (readbackPendingRef.current) return;
        readbackPendingRef.current = true;

        try {
            const attribute = engine.stateBufferRead.value;
            const backendData = gl.backend.get(attribute);
            if (!backendData || !backendData.buffer) {
                // Buffer not yet created by WebGPU backend
                readbackPendingRef.current = false;
                return;
            }

            const stateBuffer = await gl.backend.getArrayBufferAsync(attribute);
            const graph = graphRef.current;
                
                const N = network.nodes.length;
                let countSusceptible = 0;
                let countInfected = 0;
                let countResistant = 0;
                
                const stateArr = new Float32Array(stateBuffer);
                
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
                
                const now = performance.now();
                if (now - lastLogRef.current > 1000) {
                    const pos = graph.getPointPositions();
                    if (pos) {
                        console.log("Node 0 position:", pos[0], pos[1]);
                    }
                    lastLogRef.current = now;
                }
                
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
    }, [engine, network]);


  return (
    <main className="relative w-full h-screen overflow-hidden bg-[#0a0a0a]">
      <div className="absolute inset-0 z-0">
          <div 
              ref={divRef} 
              className="w-full h-full"
          />
      </div>

      <AbmCompute 
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
