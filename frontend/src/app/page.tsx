'use client';
import dynamic from 'next/dynamic';
import DashboardOverlay from '@/components/DashboardOverlay';
import { useSimulationStore } from '@/store/simulationStore';
import { useMemo, useEffect, useRef } from 'react';
import * as THREE from 'three';
// @ts-ignore
import { MeshStandardNodeMaterial, StorageBufferAttribute } from 'three/webgpu';
// @ts-ignore
import { uniform, positionLocal, vec4, vec3, vec2, select, uint, instanceIndex, color, storage, cos, sin, float, clamp, floor, distance, normalLocal, abs, max, atomicLoad, If } from 'three/tsl';

import { AgentDataStore } from '@/engine/AgentDataStore';
import { antSetupNode, antBehaviorNode } from '@/engine/physics/Ants';
import { environmentComputeNode, environmentSetupNode, trailComputeNode, trailSetupNode } from '@/engine/physics/EnvironmentGrid';
import { generateEnvironmentMap } from '@/engine/map/EnvironmentGenerator';

const AbmCanvas = dynamic(() => import('@/components/AbmCanvas'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center w-full h-screen bg-neutral-950 text-emerald-400 font-mono text-sm">
      <div className="flex flex-col items-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-emerald-500 mb-4"></div>
        <div>Initializing WebGPU Compute Pipeline...</div>
      </div>
    </div>
  )
});

export default function Home() {
  const agentCount = useSimulationStore(state => state.dynamicParams.agent_count ?? 125);
  const worldSize = useSimulationStore(state => state.dynamicParams.world_size ?? 50.0);
  const setupTrigger = useSimulationStore(state => state.setupTrigger);
  const mapType = useSimulationStore(state => state.mapType);
  
  const timeAccumulatorRef = useRef(0);
  const ticksRef = useRef(0);
  const pingPongRef = useRef(true);

  useEffect(() => {
     timeAccumulatorRef.current = 0;
     ticksRef.current = 0;
     window.dispatchEvent(new CustomEvent('abm-ticks', { detail: { ticks: 0 } }));
  }, [setupTrigger, agentCount, worldSize]);
  
  // Environment Grid Parameters
  // Fixed 128x128 grid for pheromones
  const gridDimX = 128;
  const gridDimY = 128;
  const totalGridCells = gridDimX * gridDimY;
  const cellSize = worldSize / gridDimX;
  
  const trailDimX = 1024;
  const trailDimY = 1024;
  const totalTrailCells = trailDimX * trailDimY;
  
  // Uniforms
  const evaporationRateUniform = useMemo(() => uniform(0.1), []);
  const diffusionRateUniform = useMemo(() => uniform(0.5), []);
  const pheromoneDropRateUniform = useMemo(() => uniform(60.0), []);
  const interactionRadiusUniform = useMemo(() => uniform(1.0), []);
  
  const deltaUniform = useMemo(() => uniform(1.0), []);
  const seedUniform = useMemo(() => uniform(0.0), []);
  
  const worldSizeUniform = useMemo(() => uniform(worldSize), []);
  const worldOffsetUniform = useMemo(() => uniform(worldSize / 2.0), []);
  const cellSizeUniform = useMemo(() => uniform(cellSize), []);
  const gridDimXUniform = useMemo(() => uniform(gridDimX), []);
  const gridDimYUniform = useMemo(() => uniform(gridDimY), []);
  const agentCountUniform = useMemo(() => uniform(agentCount), [agentCount]);
  const gridSizeLimitUniform = useMemo(() => uniform(totalGridCells), [totalGridCells]);
  const trailDimXUniform = useMemo(() => uniform(trailDimX), [trailDimX]);
  const trailDimYUniform = useMemo(() => uniform(trailDimY), [trailDimY]);
  const trailSizeLimitUniform = useMemo(() => uniform(totalTrailCells), [totalTrailCells]);
  const timeUniform = useMemo(() => uniform(0.0), []);
  const nestPosUniform = useMemo(() => uniform(vec2(0.0, 0.0)), []);
  const isNetLogoModeUniform = useMemo(() => uniform(uint(0)), []);
  const visualTrailsUniform = useMemo(() => uniform(uint(0)), []);

  const { store, antMaterial, envMaterial, setupPass, envSetupPass, trailSetupPass,
          envPassEven, envPassOdd, trailPassEven, trailPassOdd, antPassEven, antPassOdd, 
          patchFoodBufferAttr, patchWallBufferAttr, homeTrailA, foodTrailA, homeTrailB, foodTrailB }: any = useMemo(() => {
              
      // 1. Agent Data Store
      const store = new AgentDataStore(agentCount);
      store.addProperty('position', 2, 'vec2');
      store.addProperty('heading', 1, 'float');
      store.addProperty('state', 1, 'uint'); // 0: Foraging, 1: Returning
      store.addProperty('homeDist', 1, 'uint');
      store.addProperty('foodDist', 1, 'uint');
      store.addProperty('escapeSteps', 1, 'uint');
      store.addProperty('totalDistance', 1, 'float');
      
      const positions = store.getNode('position');
      const headings = store.getNode('heading');
      const states = store.getNode('state');
      const homeDists = store.getNode('homeDist');
      const foodDists = store.getNode('foodDist');
      const escapeSteps = store.getNode('escapeSteps');
      const totalDistances = store.getNode('totalDistance');
      
      // Setup Pass
      // @ts-ignore
      const setupPass = antSetupNode(positions, headings, states, homeDists, foodDists, escapeSteps, totalDistances, seedUniform, agentCountUniform, worldSizeUniform, nestPosUniform).compute(agentCount);
      
      // 2. Environment Grid Buffers
      // @ts-ignore
      const homeDistAAttr = new StorageBufferAttribute(new Uint32Array(totalGridCells), 1);
      // @ts-ignore
      const homeDistA = storage(homeDistAAttr, 'uint', totalGridCells);
      // @ts-ignore
      const homeDistAAtomic = storage(homeDistAAttr, 'uint', totalGridCells).toAtomic();
      
      // @ts-ignore
      const homeDistBAttr = new StorageBufferAttribute(new Uint32Array(totalGridCells), 1);
      // @ts-ignore
      const homeDistB = storage(homeDistBAttr, 'uint', totalGridCells);
      // @ts-ignore
      const homeDistBAtomic = storage(homeDistBAttr, 'uint', totalGridCells).toAtomic();
      
      // @ts-ignore
      const foodDistAAttr = new StorageBufferAttribute(new Uint32Array(totalGridCells), 1);
      // @ts-ignore
      const foodDistA = storage(foodDistAAttr, 'uint', totalGridCells);
      // @ts-ignore
      const foodDistAAtomic = storage(foodDistAAttr, 'uint', totalGridCells).toAtomic();
      
      // @ts-ignore
      const foodDistBAttr = new StorageBufferAttribute(new Uint32Array(totalGridCells), 1);
      // @ts-ignore
      const foodDistB = storage(foodDistBAttr, 'uint', totalGridCells);
      // @ts-ignore
      const foodDistBAtomic = storage(foodDistBAttr, 'uint', totalGridCells).toAtomic();
      
      // @ts-ignore
      const patchFoodBufferAttr = new StorageBufferAttribute(new Int32Array(totalGridCells), 1);
      // @ts-ignore
      const patchFoodBufferAtomic = storage(patchFoodBufferAttr, 'int', totalGridCells).toAtomic();
      // @ts-ignore
      const patchFoodBuffer = storage(patchFoodBufferAttr, 'int', totalGridCells);
      
      // @ts-ignore
      const patchWallBufferAttr = new StorageBufferAttribute(new Int32Array(totalGridCells), 1);
      // @ts-ignore
      const patchWallBuffer = storage(patchWallBufferAttr, 'int', totalGridCells);
      
      // 3. Trail Buffers
      // @ts-ignore
      const homeTrailAAttr = new StorageBufferAttribute(new Uint32Array(totalTrailCells), 1);
      // @ts-ignore
      const homeTrailA = storage(homeTrailAAttr, 'uint', totalTrailCells);
      // @ts-ignore
      const homeTrailAAtomic = storage(homeTrailAAttr, 'uint', totalTrailCells).toAtomic();
      // @ts-ignore
      const homeTrailBAttr = new StorageBufferAttribute(new Uint32Array(totalTrailCells), 1);
      // @ts-ignore
      const homeTrailB = storage(homeTrailBAttr, 'uint', totalTrailCells);
      // @ts-ignore
      const homeTrailBAtomic = storage(homeTrailBAttr, 'uint', totalTrailCells).toAtomic();
      // @ts-ignore
      const foodTrailAAttr = new StorageBufferAttribute(new Uint32Array(totalTrailCells), 1);
      // @ts-ignore
      const foodTrailA = storage(foodTrailAAttr, 'uint', totalTrailCells);
      // @ts-ignore
      const foodTrailAAtomic = storage(foodTrailAAttr, 'uint', totalTrailCells).toAtomic();
      // @ts-ignore
      const foodTrailBAttr = new StorageBufferAttribute(new Uint32Array(totalTrailCells), 1);
      // @ts-ignore
      const foodTrailB = storage(foodTrailBAttr, 'uint', totalTrailCells);
      // @ts-ignore
      const foodTrailBAtomic = storage(foodTrailBAttr, 'uint', totalTrailCells).toAtomic();
      
      // @ts-ignore
      const envSetupPass = environmentSetupNode(homeDistAAtomic, homeDistBAtomic, foodDistAAtomic, foodDistBAtomic, patchFoodBuffer, worldSizeUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, gridSizeLimitUniform, seedUniform, isNetLogoModeUniform).compute(totalGridCells);
      
      // @ts-ignore
      const trailSetupPass = trailSetupNode(homeTrailAAtomic, homeTrailBAtomic, foodTrailAAtomic, foodTrailBAtomic, trailSizeLimitUniform).compute(totalTrailCells);
      
      // 4. Compute Passes (Ping Pong)
      // EVEN FRAME: Env updates A->B, Ants read/write B
      // @ts-ignore
      const envPassEven = environmentComputeNode(homeDistAAtomic, homeDistBAtomic, foodDistAAtomic, foodDistBAtomic, evaporationRateUniform, diffusionRateUniform, gridDimXUniform, gridDimYUniform, gridSizeLimitUniform, patchWallBuffer, isNetLogoModeUniform).compute(totalGridCells);
      // @ts-ignore
      const trailPassEven = trailComputeNode(homeTrailAAtomic, homeTrailBAtomic, foodTrailAAtomic, foodTrailBAtomic, trailDimXUniform, trailDimYUniform, trailSizeLimitUniform).compute(totalTrailCells);
      // @ts-ignore
      const antPassEven = antBehaviorNode(headings, states, homeDists, foodDists, escapeSteps, totalDistances, homeDistBAtomic, foodDistBAtomic, positions, timeUniform, agentCountUniform, deltaUniform, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, patchFoodBufferAtomic, worldSizeUniform, patchWallBuffer, nestPosUniform, isNetLogoModeUniform, pheromoneDropRateUniform, homeTrailBAtomic, foodTrailBAtomic, trailDimXUniform, trailDimYUniform).compute(agentCount);
      
      // ODD FRAME: Env updates B->A, Ants read/write A
      // @ts-ignore
      const envPassOdd = environmentComputeNode(homeDistBAtomic, homeDistAAtomic, foodDistBAtomic, foodDistAAtomic, evaporationRateUniform, diffusionRateUniform, gridDimXUniform, gridDimYUniform, gridSizeLimitUniform, patchWallBuffer, isNetLogoModeUniform).compute(totalGridCells);
      // @ts-ignore
      const trailPassOdd = trailComputeNode(homeTrailBAtomic, homeTrailAAtomic, foodTrailBAtomic, foodTrailAAtomic, trailDimXUniform, trailDimYUniform, trailSizeLimitUniform).compute(totalTrailCells);
      // @ts-ignore
      const antPassOdd = antBehaviorNode(headings, states, homeDists, foodDists, escapeSteps, totalDistances, homeDistAAtomic, foodDistAAtomic, positions, timeUniform, agentCountUniform, deltaUniform, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, patchFoodBufferAtomic, worldSizeUniform, patchWallBuffer, nestPosUniform, isNetLogoModeUniform, pheromoneDropRateUniform, homeTrailAAtomic, foodTrailAAtomic, trailDimXUniform, trailDimYUniform).compute(agentCount);


      const antMaterial = new MeshStandardNodeMaterial();
      
      const stateVal = states.element(instanceIndex);
      const isReturning = stateVal.equal(uint(1));
      
      const chitinColor = select(isReturning, color(0xff4477), color(0xffcc44)); // Pink returning, yellow foraging
      
      antMaterial.colorNode = chitinColor;
      antMaterial.roughnessNode = float(0.2); // shiny chitin
      antMaterial.metalnessNode = float(0.1); 
      
      const antHeading = headings.element(instanceIndex);
      const antPos = positions.element(instanceIndex);
      
      const cosA = cos(antHeading);
      const sinA = sin(antHeading);
      
      const rotatedX = positionLocal.x.mul(cosA).sub(positionLocal.y.mul(sinA));
      const rotatedY = positionLocal.x.mul(sinA).add(positionLocal.y.mul(cosA));
      
      // Place ants slightly above the displaced terrain
      // @ts-ignore
      antMaterial.positionNode = vec3(rotatedX, rotatedY, positionLocal.z.add(0.5)).add(vec3(antPos.x, antPos.y, 0.0));
      
      // 6. Environment Background Material
      const envMaterial = new MeshStandardNodeMaterial();
      // @ts-ignore
      const uv = positionLocal.add(vec3(worldOffsetUniform, worldOffsetUniform, 0.0)).div(worldSizeUniform);
      const col = uint(clamp(floor(uv.x.mul(gridDimXUniform)), float(0), float(gridDimXUniform).sub(1.0)));
      const row = uint(clamp(floor(uv.y.mul(gridDimYUniform)), float(0), float(gridDimYUniform).sub(1.0)));
      const idx = row.mul(uint(gridDimXUniform)).add(col);
      
      const homeDistVal = float(homeDistA.element(idx));
      const foodDistVal = float(foodDistA.element(idx));
      
      const maxVisualDistHome = float(1500.0);
      const maxVisualDistFood = float(30000.0);
      const isNetLogoMode = isNetLogoModeUniform.equal(1);
      
      const homePheromone = select(isNetLogoMode, float(0.0), max(float(0.0), float(1.0).sub(homeDistVal.div(maxVisualDistHome))));
      const foodPheromone = select(isNetLogoMode, clamp(foodDistVal.div(5000.0), 0.0, 1.0), max(float(0.0), float(1.0).sub(foodDistVal.div(maxVisualDistFood))));
      
      const foodVal = float(patchFoodBuffer.element(idx));
      const isWall = patchWallBuffer.element(idx).equal(1);
      
      const worldPosX = uv.x.mul(worldSizeUniform).sub(worldOffsetUniform);
      const worldPosY = uv.y.mul(worldSizeUniform).sub(worldOffsetUniform);
      
      const distNest = distance(vec2(worldPosX, worldPosY), nestPosUniform);
      const nestRadius = worldSizeUniform.mul(0.1);
      const isNest = distNest.lessThan(nestRadius);
      const isFood = foodVal.greaterThan(0);
      
      const baseDirt = color(0x353535); // Clean dark grey graph paper
      
      const isWetHome = select(isNetLogoMode, clamp(homePheromone.mul(0.01), 0.0, 1.0), float(0.0));
      const isWetFood = select(isNetLogoMode, clamp(foodPheromone.mul(0.01), 0.0, 1.0), float(0.0));
      
      const homeColor = color(0x4477ff); // Blue pheromone (ToHome)
      const toFoodColor = color(0x00ff00); // Green pheromone (ToFood)
      
      const foodCol = color(0xffdf66);  // Yellow food pallets (brighter, like the image)
      const wallCol = color(0x666666);  // Grey wall
      
      // Grid lines - aligned with the patches (cellSizeUniform)
      const normX = worldPosX.add(worldOffsetUniform);
      const normY = worldPosY.add(worldOffsetUniform);
      const gridX = normX.mod(cellSizeUniform);
      const gridY = normY.mod(cellSizeUniform);
      
      // Clean grid lines (graph paper style), slightly thicker to avoid Moire alias patterns
      const lineThickness = cellSizeUniform.mul(0.08); 
      const isGrid = gridX.lessThan(lineThickness).or(gridY.lessThan(lineThickness));
      
      // Draw pure graph paper
      const terrainWithGrid = select(isGrid, color(0x4a4a4a), baseDirt);
      
      // Food visuals - individual pallets (circles inside the grid cells)
      const cellCenterDist = distance(vec2(gridX, gridY), vec2(cellSizeUniform.mul(0.5), cellSizeUniform.mul(0.5)));
      const isFoodCircle = isFood.and(cellCenterDist.lessThan(cellSizeUniform.mul(0.40))); 
      
      // Nest visuals
      const isNestCenter = distNest.lessThan(nestRadius.mul(0.05));
      const isNestBorder = distNest.greaterThan(nestRadius.mul(0.95)).and(distNest.lessThan(nestRadius));
      const nestBodyCol = terrainWithGrid.add(color(0x0a0a0a)); // Barely lighter, preserving graph paper
      const nestCol = select(isNestCenter, color(0xff4477), select(isNestBorder, color(0xffffff), nestBodyCol));
      
      envMaterial.colorNode = select(isWall, wallCol, select(isNest, nestCol, select(isFoodCircle, foodCol, terrainWithGrid)));
      const isWet = isWetHome.add(isWetFood);
      
      const trailNormX = positionLocal.x.add(worldSizeUniform.div(2.0)).div(worldSizeUniform);
      const trailNormY = positionLocal.y.add(worldSizeUniform.div(2.0)).div(worldSizeUniform);
      const trailCol = uint(clamp(floor(trailNormX.mul(trailDimXUniform)), float(0.0), trailDimXUniform.sub(1.0)));
      const trailRow = uint(clamp(floor(trailNormY.mul(trailDimYUniform)), float(0.0), trailDimYUniform.sub(1.0)));
      const trailIdx = trailRow.mul(uint(trailDimXUniform)).add(trailCol);
      
      const tHomeVal = float(homeTrailA.element(trailIdx)).div(1000.0);
      const tFoodVal = float(foodTrailA.element(trailIdx)).div(1000.0);
      const tWetHome = clamp(tHomeVal.mul(100.0), 0.0, 1.0);
      const tWetFood = clamp(tFoodVal.mul(100.0), 0.0, 1.0);
      
      const emissiveHome = select(visualTrailsUniform.equal(1), homeColor.mul(tWetHome).mul(0.5), homeColor.mul(isWetHome).mul(0.5));
      const emissiveFood = select(visualTrailsUniform.equal(1), toFoodColor.mul(tWetFood).mul(0.5), toFoodColor.mul(isWetFood).mul(0.5));
      const combinedEmissive = emissiveHome.add(emissiveFood);
      
      envMaterial.emissiveNode = select(isWall, color(0x000000), select(isNest, color(0x000000), select(isFoodCircle, color(0x000000), combinedEmissive)));
      
      const dryRoughness = float(0.9);
      const wetRoughness = float(0.1);
      envMaterial.roughnessNode = select(isNest, float(1.0), dryRoughness.mix(wetRoughness, isWet));
      
      const dryMetalness = float(0.0);
      const wetMetalness = float(0.2);
      envMaterial.metalnessNode = select(isNest, float(0.0), dryMetalness.mix(wetMetalness, isWet));
      
      const dispNest = select(isNest, float(-1.0), float(0.0));
      const dispFood = float(foodVal).mul(0.1); // food mound
      const dispWall = select(isWall, float(2.0), float(0.0)); // wall height
      const dispVal = dispNest.add(dispFood).add(dispWall);
      
      // @ts-ignore
      envMaterial.positionNode = positionLocal.add(normalLocal.mul(dispVal));
      
      return { store, antMaterial, envMaterial, setupPass, envSetupPass, trailSetupPass, envPassEven, envPassOdd, trailPassEven, trailPassOdd, antPassEven, antPassOdd, patchFoodBufferAttr, patchWallBufferAttr, homeTrailA, foodTrailA, homeTrailB, foodTrailB };
  }, [agentCount, worldSize, cellSize, totalGridCells, totalTrailCells]);

  // CPU Map Generation Hook
  useEffect(() => {
     if (patchWallBufferAttr && patchFoodBufferAttr) {
         if (mapType.startsWith('maze_')) {
            const offsetX = worldSize * 0.422; 
            const offsetY = -worldSize * 0.422; 
            nestPosUniform.value.set(offsetX, offsetY);
        } else {
            nestPosUniform.value.set(0.0, 0.0);
        }
         
         if (mapType === 'open_world') {
             isNetLogoModeUniform.value = 1;
         } else {
             isNetLogoModeUniform.value = 0;
         }
         
         const wallArray = patchWallBufferAttr.array as Int32Array;
         const foodArray = patchFoodBufferAttr.array as Int32Array;
         generateEnvironmentMap(mapType, gridDimX, gridDimY, wallArray, foodArray, Math.floor(Math.random() * 10000));
         
         patchWallBufferAttr.needsUpdate = true;
         patchFoodBufferAttr.needsUpdate = true;
     }
  }, [setupTrigger, mapType, patchWallBufferAttr, patchFoodBufferAttr, gridDimX, gridDimY, worldSize, nestPosUniform]);

  useEffect(() => {
    return () => {
      store.dispose();
      patchFoodBufferAttr.dispose();
      patchWallBufferAttr.dispose();
      antMaterial.dispose();
      envMaterial.dispose();
    };
  }, [store, antMaterial, envMaterial, patchFoodBufferAttr, patchWallBufferAttr]);
  
  // Render Callback
  const frameIndexRef = useRef(0);
  const telemetryDataRef = useRef(new Uint32Array(3));
  const readbackPendingRef = useRef(false);

  const renderCallback = async (gl: any, delta: number) => {
      const currentIsPaused = useSimulationStore.getState().isPaused;
      
      if (!currentIsPaused) {
          const modelSpeed = useSimulationStore.getState().dynamicParams.model_speed ?? 1.0;
          timeAccumulatorRef.current += delta * modelSpeed;
          const fixedDelta = 1.0 / 60.0;
          
          deltaUniform.value = fixedDelta;
          
          let steps = 0;
          while (timeAccumulatorRef.current >= fixedDelta && steps < 10) {
              timeUniform.value += fixedDelta;
              seedUniform.value = Math.random();
              
              if (pingPongRef.current) {
                  gl.compute(envPassEven);
                  gl.compute(trailPassEven);
                  gl.compute(antPassEven);
              } else {
                  gl.compute(envPassOdd);
                  gl.compute(trailPassOdd);
                  gl.compute(antPassOdd);
              }
              pingPongRef.current = !pingPongRef.current;
              
              timeAccumulatorRef.current -= fixedDelta;
              ticksRef.current++;
              steps++;
          }
          
          if (steps > 0) {
              window.dispatchEvent(new CustomEvent('abm-ticks', { detail: { ticks: ticksRef.current } }));
          }
      }
      
      if (!readbackPendingRef.current) {
          readbackPendingRef.current = true;
          try {
              const stateBufferAsync = gl.backend.getArrayBufferAsync(store.attributes['state']);
              const distBufferAsync = gl.backend.getArrayBufferAsync(store.attributes['totalDistance']);
              const [foodBuffer, stateBuffer, distBuffer] = await Promise.all([
                  gl.backend.getArrayBufferAsync(patchFoodBufferAttr),
                  stateBufferAsync,
                  distBufferAsync
              ]);
              const arr = new Int32Array(foodBuffer);
              const statesArr = new Uint32Array(stateBuffer);
              const distArr = new Float32Array(distBuffer);
              
              let transiting = 0;
              let totalDist = 0;
              for (let i = 0; i < agentCount; i++) {
                 if (statesArr[i] === 1) transiting++;
                 totalDist += distArr[i];
              }

              let f1 = 0, f2 = 0, f3 = 0;
              for (let y = 0; y < gridDimY; y++) {
                 for (let x = 0; x < gridDimX; x++) {
                    const food = arr[y * gridDimX + x];
                    if (food === 0) continue;
                    const worldX = (x + 0.5) * cellSize - worldSize / 2;
                    const worldY = (y + 0.5) * cellSize - worldSize / 2;
                    const offset = worldSize * 0.4;
                    const r = worldSize * 0.08;
                    
                    if (Math.hypot(worldX - offset, worldY - offset) < r) f1 += food;
                    else if (Math.hypot(worldX - offset, worldY + offset) < r) f2 += food;
                    else if (Math.hypot(worldX + offset, worldY - offset) < r) f3 += food;
                 }
              }
              telemetryDataRef.current[0] = f1;
              telemetryDataRef.current[1] = f2;
              telemetryDataRef.current[2] = f3;
              
              window.dispatchEvent(new CustomEvent('abm-telemetry', {
                  detail: { food: [f1, f2, f3], transiting, totalDist }
              }));
          } catch (e) {
              console.warn("Readback error", e);
          } finally {
              readbackPendingRef.current = false;
          }
      }
  };

  return (
    <main className="relative h-screen w-full overflow-hidden bg-neutral-900">
      <DashboardOverlay />
      <AbmCanvas 
         agentCount={agentCount} 
         antMaterial={antMaterial} 
         envMaterial={envMaterial}
         setupPass={setupPass} 
         envSetupPass={envSetupPass}
         trailSetupPass={trailSetupPass}
         computePasses={[]} 
         renderCallback={renderCallback}
         updateUniforms={() => {
            const params = useSimulationStore.getState().dynamicParams;
            evaporationRateUniform.value = params.evaporation_rate ?? 0.1;
            diffusionRateUniform.value = params.diffusion_rate ?? 0.5;
            pheromoneDropRateUniform.value = params.pheromone_drop_rate ?? 60.0;
            interactionRadiusUniform.value = params.interaction_radius ?? 1.0;
            worldSizeUniform.value = params.world_size ?? 50.0;
            worldOffsetUniform.value = (params.world_size ?? 50.0) / 2.0;
            cellSizeUniform.value = (params.world_size ?? 50.0) / 128.0;
            isNetLogoModeUniform.value = useSimulationStore.getState().mapType === 'netlogo' ? 1 : 0;
            visualTrailsUniform.value = useSimulationStore.getState().visualTrails ? 1 : 0;
         }}
         worldSize={worldSize}
      />
    </main>
  );
}
