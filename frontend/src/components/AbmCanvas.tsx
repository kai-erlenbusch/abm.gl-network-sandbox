'use client';
import { useRef, useEffect, useMemo } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { WebGPURenderer, Node } from 'three/webgpu';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
Node.captureStackTrace = true;
import { useSimulationStore } from '@/store/simulationStore';

export interface AbmCanvasProps {
  agentCount: number;
  worldSize?: number;
  antMaterial: any; 
  envMaterial: any;
  setupPass: any; 
  envSetupPass?: any;
  trailSetupPass?: any;
  computePasses: any[]; 
  renderCallback?: (gl: any, delta: number) => void;
  updateUniforms?: () => void;
}

function AbmEngine({ agentCount, worldSize = 250, antMaterial, envMaterial, setupPass, envSetupPass, trailSetupPass, computePasses, renderCallback, updateUniforms }: AbmCanvasProps) {
  const meshRef = useRef<THREE.InstancedMesh>(null);
  const needsSetupRef = useRef(true);
  const lastSetupTrigger = useRef(0);
  
  const setupTrigger = useSimulationStore(state => state.setupTrigger);
  const isPaused = useSimulationStore(state => state.isPaused);

  useEffect(() => {
    if (setupTrigger > lastSetupTrigger.current) {
      needsSetupRef.current = true;
      lastSetupTrigger.current = setupTrigger;
    }
  }, [setupTrigger]);

  useFrame(async (state, delta) => {
    if (!meshRef.current) return;
    if (!(state.gl as any).__initialized) return;

    // Trigger FPS telemetry event
    window.dispatchEvent(new CustomEvent('abm-frame'));

    const gl = state.gl as any;

    if (updateUniforms) {
        updateUniforms();
    }

    if (needsSetupRef.current) {
        if (setupPass) gl.compute(setupPass);
        if (envSetupPass) gl.compute(envSetupPass);
        if (trailSetupPass) gl.compute(trailSetupPass);
        needsSetupRef.current = false;
    }

    if (!isPaused && computePasses.length > 0) {
        try {
          for (const pass of computePasses) {
             if (pass) gl.compute(pass);
          }
        } catch (e) {
            console.error("Compute Pass Error:", e);
        }
    }

    if (renderCallback) {
       renderCallback(gl, delta);
    }
  });

  const antGeometry = useMemo(() => {
      const geometries: THREE.BufferGeometry[] = [];
      
      // Abdomen (large tear-drop at the back)
      const abdomen = new THREE.SphereGeometry(0.25, 12, 12);
      abdomen.scale(1.2, 0.8, 0.8);
      abdomen.translate(-0.4, 0, 0.1);
      geometries.push(abdomen);
      
      // Thorax (central pill)
      const thorax = new THREE.CapsuleGeometry(0.12, 0.3, 8, 8);
      thorax.rotateZ(-Math.PI / 2);
      thorax.translate(0.1, 0, 0.15);
      geometries.push(thorax);
      
      // Head (front sphere)
      const head = new THREE.SphereGeometry(0.18, 12, 12);
      head.translate(0.45, 0, 0.15);
      geometries.push(head);
      
      // Mandibles
      const mandLeft = new THREE.CapsuleGeometry(0.04, 0.15, 4, 4);
      mandLeft.rotateZ(-Math.PI / 4);
      mandLeft.translate(0.6, 0.1, 0.15);
      geometries.push(mandLeft);
      
      const mandRight = new THREE.CapsuleGeometry(0.04, 0.15, 4, 4);
      mandRight.rotateZ(Math.PI / 4);
      mandRight.translate(0.6, -0.1, 0.15);
      geometries.push(mandRight);
      
      // Legs (3 pairs)
      const legPositions = [-0.05, 0.1, 0.25];
      for (let i = 0; i < 3; i++) {
          const xOffset = legPositions[i];
          
          // Left Leg
          const legL = new THREE.CapsuleGeometry(0.03, 0.4, 4, 4);
          legL.rotateX(Math.PI / 3);
          legL.rotateZ(Math.PI / 6);
          legL.translate(xOffset, 0.25, 0.1);
          geometries.push(legL);
          
          // Right Leg
          const legR = new THREE.CapsuleGeometry(0.03, 0.4, 4, 4);
          legR.rotateX(-Math.PI / 3);
          legR.rotateZ(Math.PI / 6);
          legR.translate(xOffset, -0.25, 0.1);
          geometries.push(legR);
      }
      
      // Merge all parts
      const mergedGeo = mergeGeometries(geometries);
      return mergedGeo;
  }, []);

  useEffect(() => {
      return () => {
          antGeometry.dispose();
      };
  }, [antGeometry]);

  return (
    <>
      {/* Background Environment Grid */}
      <mesh position={[0, 0, 0]} receiveShadow>
         <planeGeometry args={[worldSize, worldSize, 128, 128]} />
         {envMaterial && <primitive object={envMaterial} attach="material" />}
      </mesh>

      {/* Ants */}
      <instancedMesh ref={meshRef} args={[antGeometry, antMaterial, agentCount]} frustumCulled={false} castShadow receiveShadow>
      </instancedMesh>
      

    </>
  );
}

// Global renderer instance trick to work with R3F
let globalRenderer: any = null;

import { OrbitControls } from '@react-three/drei';

export default function AbmCanvas(props: AbmCanvasProps) {
  return (
    <div className="w-full h-screen absolute inset-0 z-0 bg-neutral-950">
      <Canvas
        camera={{ position: [0, -60, 60], fov: 45, up: [0, 0, 1] }}
        gl={(canvasProp) => {
            const actualCanvas = (canvasProp && (canvasProp as any).canvas) ? (canvasProp as any).canvas : canvasProp;
            const renderer = new WebGPURenderer({ 
                canvas: actualCanvas as HTMLCanvasElement, 
                antialias: false, 
                powerPreference: 'high-performance',
                // @ts-ignore
                requiredLimits: { maxStorageBuffersPerShaderStage: 16 }
            });
            
            renderer.init().then(() => {
                renderer.__initialized = true;
                renderer.shadowMap.enabled = true;
                renderer.shadowMap.type = THREE.PCFSoftShadowMap;
            }).catch((e: any) => {
                console.error("WebGPU Initialization Failed", e);
            });
            
            // WebGPURenderer requires async init(), but R3F calls render() synchronously.
            // We must mock the render and compute methods until it's ready.
            const originalRender = renderer.render.bind(renderer);
            const originalCompute = renderer.compute.bind(renderer);
            
            renderer.render = (...args: any[]) => {
               if (renderer.__initialized) {
                   if (args.length > 2) console.log("RENDER ARGS HAS TARGET?", args[2]);
                   originalRender(args[0], args[1]); // Force only scene and camera
               }
            };
            
            renderer.compute = (...args: any[]) => {
                if (renderer.__initialized) {
                    try {
                        const result = originalCompute(...args);
                        if (result && typeof result.catch === 'function') {
                            result.catch((e: any) => {
                                // Ignore async rejections
                            });
                        }
                    } catch (e) {
                        throw e;
                    }
               }
            };

            return renderer;
        }}
      >
        <OrbitControls makeDefault maxPolarAngle={Math.PI / 2.1} minDistance={10} maxDistance={150} />
        <color attach="background" args={['#0a0a0a']} />
        <ambientLight intensity={1.5} />
        <directionalLight 
           position={[10, -30, 50]} 
           intensity={3.0} 
           castShadow 
           shadow-mapSize={[2048, 2048]}
        >
           <orthographicCamera attach="shadow-camera" args={[-100, 100, 100, -100, 0.1, 200]} />
        </directionalLight>
        <AbmEngine {...props} />
      </Canvas>
    </div>
  );
}
