'use client';
import { useRef, useEffect } from 'react';
import { useSimulationStore } from '@/store/simulationStore';

export interface AbmComputeProps {
  engine: any;
  setupPass: any; 
  computePasses: any[]; 
  renderCallback?: (gl: any, delta: number, ticksToRun: number, engine: any) => any;
  updateUniforms?: () => void;
}

export default function AbmCompute({ engine, setupPass, computePasses, renderCallback, updateUniforms }: AbmComputeProps) {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const rendererRef = useRef<any>(null);
    const rafRef = useRef<number>(0);
    const needsSetupRef = useRef(true);
    const timeAccumulator = useRef(0);
    const lastTimeRef = useRef(0);

    const isPaused = useSimulationStore(state => state.isPaused);
    const modelSpeed = useSimulationStore((state: any) => state.dynamicParams.model_speed ?? 1.0);

    const propsRef = useRef({ engine, setupPass, computePasses, renderCallback, updateUniforms });
    propsRef.current = { engine, setupPass, computePasses, renderCallback, updateUniforms };

    const prevSetupPassRef = useRef(setupPass);
    if (prevSetupPassRef.current !== setupPass) {
        prevSetupPassRef.current = setupPass;
        if (setupPass) {
            needsSetupRef.current = true;
        }
    }

    useEffect(() => {
        if (!canvasRef.current) return;

        let active = true;
        
        // Initialize WebGPURenderer manually, completely isolated from R3F
        const initGPU = async () => {
            const { WebGPURenderer } = require('three/webgpu');
            const renderer = new WebGPURenderer({ canvas: canvasRef.current, antialias: false });
            await renderer.init();
            if (!active) return;
            
            rendererRef.current = renderer;
            (window as any).__RENDERER = renderer;
            lastTimeRef.current = performance.now();
            loop(performance.now());
        };

        const loop = (now: number) => {
            if (!active) return;
            rafRef.current = requestAnimationFrame(loop);

            const renderer = rendererRef.current;
            if (!renderer) return;

            window.dispatchEvent(new CustomEvent('abm-render-frame'));

            const deltaMs = now - lastTimeRef.current;
            lastTimeRef.current = now;
            const delta = deltaMs / 1000.0;

            const { engine, setupPass, computePasses, renderCallback, updateUniforms } = propsRef.current;

            if (needsSetupRef.current && setupPass) {
                console.log("[AbmCanvas] Running setupPass");
                
                try {
                    renderer.compute(setupPass);
                    console.log("[AbmCanvas] setupPass computed successfully");
                } catch (e) {
                    console.error("[AbmCanvas] setupPass failed", e);
                }
                needsSetupRef.current = false;
            }

            let finalTicksToRun = 0;
            if (!useSimulationStore.getState().isPaused && computePasses.length > 0) {
                try {
                    // Use modelSpeed from current state snapshot
                    const currentSpeed = useSimulationStore.getState().dynamicParams.model_speed ?? 1.0;
                    const ticksPerSecond = currentSpeed * 6.0; 
                    let ticksToRun = 0;

                    if (ticksPerSecond <= 0) {
                        ticksToRun = 0;
                    } else if (ticksPerSecond >= 60) {
                        ticksToRun = Math.floor(ticksPerSecond / 60) || 1;
                    } else {
                        const safeDelta = Math.min(delta, 0.1);
                        timeAccumulator.current += safeDelta;
                        const tickInterval = 1.0 / ticksPerSecond;
                        while (timeAccumulator.current >= tickInterval) {
                            ticksToRun++;
                            timeAccumulator.current -= tickInterval;
                        }
                    }
                    
                    ticksToRun = Math.min(ticksToRun, 60);
                    finalTicksToRun = ticksToRun;

                    if (ticksToRun > 0) {
                        console.log(`[AbmCanvas] Running ${ticksToRun} ticks...`);
                    }

                    for (let i = 0; i < ticksToRun; i++) {
                        if (updateUniforms) updateUniforms();
                        for (const pass of computePasses) {
                            if (pass) {
                                console.log("[AbmCanvas] Dispatching compute pass:", pass);
                                renderer.compute(pass);
                            } else {
                                console.error("[AbmCanvas] computePass is null/undefined!");
                            }
                        }
                    }

                    if (renderCallback && finalTicksToRun > 0) {
                        try {
                            const result = renderCallback(renderer, delta, finalTicksToRun, propsRef.current.engine);
                            if (result instanceof Promise) {
                                result.catch(e => console.error("[AbmCanvas] renderCallback error", e));
                            }
                        } catch (e) {
                            console.error("[AbmCanvas] renderCallback error", e);
                        }
                    } else if (renderCallback && finalTicksToRun === 0) {
                        renderCallback(renderer, delta, 0, propsRef.current.engine);
                    }
                } catch (e) {
                    console.error("Compute Pass Error:", e);
                }
            } else {
                // If paused or no passes, just pass 0 to renderCallback
                finalTicksToRun = 0;
                if (renderCallback) {
                    renderCallback(renderer, delta, finalTicksToRun, propsRef.current.engine)?.catch((e: any) => console.error("Render callback error", e));
                }
            }
        };

        initGPU().catch(e => console.error("WebGPU init failed:", e));

        return () => {
            active = false;
            cancelAnimationFrame(rafRef.current);
            if (rendererRef.current) {
                rendererRef.current.dispose();
            }
        };
    }, []);

    return (
        <canvas 
            ref={canvasRef} 
            style={{ position: 'absolute', opacity: 0, pointerEvents: 'none', width: '1px', height: '1px' }} 
        />
    );
}
