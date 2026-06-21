// @ts-ignore
import { storage, float, Fn, If, uint, vec4, instanceIndex, Loop, uniform, mod } from 'three/tsl';
import { StorageInstancedBufferAttribute } from 'three/webgpu';
import { prngHash } from '../math/PRNG';

export const MAX_NODES = 50000;

export class VirusDynamicsEngine {
    agentCount: number;

    stateBufferRead: any;
    stateBufferWrite: any;
    
    neighborCounts: any;
    neighborStartIndices: any;
    neighborDestinations: any;

    setupPass: any;
    simulationPass: any;
    copyPass: any;

    uniforms: {
        virusSpreadChance: any;
        virusCheckFrequency: any;
        recoveryChance: any;
        gainResistanceChance: any;
        randomSeed: any;
    };

    constructor(agentCount = MAX_NODES, totalEdges = 0) {
        this.agentCount = agentCount;

        this.uniforms = {
            virusSpreadChance: uniform(0.025),
            virusCheckFrequency: uniform(1.0),
            recoveryChance: uniform(0.05),
            gainResistanceChance: uniform(0.05),
            randomSeed: uniform(Math.random())
        };

        this.stateBufferRead = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        this.stateBufferWrite = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        
        this.neighborCounts = storage(new StorageInstancedBufferAttribute(new Uint32Array(agentCount), 1), 'uint', agentCount);
        this.neighborStartIndices = storage(new StorageInstancedBufferAttribute(new Uint32Array(agentCount), 1), 'uint', agentCount);
        this.neighborDestinations = storage(new StorageInstancedBufferAttribute(new Uint32Array(totalEdges), 1), 'uint', totalEdges);

        this.setupPass = Fn(() => {
            const i = instanceIndex;
            // Prevent compiler from optimizing out the buffers by copying initial data to the write buffer
            this.stateBufferWrite.element(i).assign(this.stateBufferRead.element(i));
        })().compute(this.agentCount);

        const rand = Fn(([seed]: any) => {
            // Pseudo-random hash using properly distributed PRNG
            return prngHash(uint(seed.mul(10000.0)));
        });

        this.simulationPass = Fn(() => {
            const i = instanceIndex;
            
            const currentData = this.stateBufferRead.element(i);
            const currentState = currentData.x;
            const currentTimer = currentData.y.toVar();
            const totalTicks = currentData.z.toVar();
            
            // Timer update
            currentTimer.addAssign(1.0);
            totalTicks.addAssign(1.0);
            If(currentTimer.greaterThanEqual(this.uniforms.virusCheckFrequency), () => {
                currentTimer.assign(0.0);
            });
            
            const nextState = currentState.toVar();
            
            // Random base seed for this node for this tick
            const rSeed = this.uniforms.randomSeed.add(float(i).mul(0.1)).add(mod(totalTicks, 10000.0).mul(13.37));
            
            If(currentState.equal(0.0), () => {
                // Susceptible: Pull infection
                const myNeighborCount = this.neighborCounts.element(i);
                const startIdx = this.neighborStartIndices.element(i);
                const infectedNeighbors = float(0.0).toVar();
                
                Loop({ start: uint(0), end: myNeighborCount, type: 'uint', condition: '<' }, ({ i: j }: any) => {
                    const neighborIdx = this.neighborDestinations.element(startIdx.add(j));
                    const nState = this.stateBufferRead.element(neighborIdx).x;
                    If(nState.equal(1.0), () => {
                        infectedNeighbors.addAssign(1.0);
                    });
                });
                
                If(infectedNeighbors.greaterThan(0.0), () => {
                    const pSpread = this.uniforms.virusSpreadChance;
                    const pSafe = float(1.0).sub(pSpread);
                    const pSafeTotal = pSafe.pow(infectedNeighbors);
                    const pInfect = float(1.0).sub(pSafeTotal);
                    
                    const roll = rand(rSeed);
                    If(roll.lessThan(pInfect), () => {
                        nextState.assign(1.0); // Become Infected
                    });
                });
                
            }).ElseIf(currentState.equal(1.0), () => {
                // Infected: Check for recovery
                If(currentTimer.equal(0.0), () => {
                    const rollRecovery = rand(rSeed.add(1.0));
                    If(rollRecovery.lessThan(this.uniforms.recoveryChance), () => {
                        const rollResist = rand(rSeed.add(2.0));
                        If(rollResist.lessThan(this.uniforms.gainResistanceChance), () => {
                            nextState.assign(2.0); // Resistant
                        }).Else(() => {
                            nextState.assign(0.0); // Susceptible
                        });
                    });
                });
            });
            
            this.stateBufferWrite.element(i).assign(vec4(nextState, currentTimer, totalTicks, 0.0));
        })().compute(this.agentCount);

        this.copyPass = Fn(() => {
            const i = instanceIndex;
            this.stateBufferRead.element(i).assign(this.stateBufferWrite.element(i));
        })().compute(this.agentCount);
    }
}
