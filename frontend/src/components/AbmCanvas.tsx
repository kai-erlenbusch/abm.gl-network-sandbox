'use client';
import { useRef, useEffect } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { useSimulationStore } from '@/store/simulationStore';

export interface AbmComputeProps {
  setupPass: any; 
  computePasses: any[]; 
  renderCallback?: (gl: any, delta: number, ticksToRun: number) => void;
  updateUniforms?: () => void;
}

function ComputeEngine({ setupPass, computePasses, renderCallback, updateUniforms }: AbmComputeProps) {
  const needsSetupRef = useRef(true);
  const lastSetupTrigger = useRef(0);
  
  const setupTrigger = useSimulationStore(state => state.setupTrigger);
  const isPaused = useSimulationStore(state => state.isPaused);

  const modelSpeed = useSimulationStore((state: any) => state.dynamicParams.model_speed ?? 1.0);
  const timeAccumulator = useRef(0);

  useEffect(() => {
    if (setupPass) {
      needsSetupRef.current = true;
    }
  }, [setupPass]);

  useFrame((state, delta) => {
    if (!(state.gl as any).__initialized) return;

    window.dispatchEvent(new CustomEvent('abm-render-frame'));

    const gl = state.gl as any;

    if (needsSetupRef.current && setupPass) {
        if (updateUniforms) updateUniforms();
        gl.compute(setupPass);
        needsSetupRef.current = false;
    }

    let finalTicksToRun = 0;
    if (!isPaused && computePasses.length > 0) {
        try {
          const ticksPerSecond = modelSpeed * 6.0; // scale up to 60 TPS at max speed
          let ticksToRun = 0;

          if (ticksPerSecond <= 0) {
              ticksToRun = 0;
          } else if (ticksPerSecond >= 60) {
              ticksToRun = Math.floor(ticksPerSecond / 60) || 1;
          } else {
              timeAccumulator.current += delta;
              const tickInterval = 1.0 / ticksPerSecond;
              while (timeAccumulator.current >= tickInterval) {
                  ticksToRun++;
                  timeAccumulator.current -= tickInterval;
              }
          }

          finalTicksToRun = ticksToRun;
          for (let i = 0; i < ticksToRun; i++) {
              if (updateUniforms) updateUniforms();
              for (const pass of computePasses) {
                 if (pass) gl.compute(pass);
              }
          }
        } catch (e) {
            console.error("Compute Pass Error:", e);
        }
    }

    if (renderCallback) {
       renderCallback(gl, delta, finalTicksToRun)?.catch((e: any) => console.error("Render callback error", e));
    }
  });

  return null;
}

export default function AbmCompute(props: AbmComputeProps) {
    return (
        <div style={{ position: 'absolute', opacity: 0, pointerEvents: 'none', width: '1px', height: '1px' }}>
            <Canvas gl={(canvas) => {
                const renderer = new (require('three/webgpu').WebGPURenderer)({ canvas, antialias: false });
                renderer.render = () => {}; // We only use compute, prevent R3F from auto-rendering scene
                renderer.init().then(() => {
                    (renderer as any).__initialized = true;
                });
                return renderer;
            }}>
                <ComputeEngine {...props} />
            </Canvas>
        </div>
    );
}
