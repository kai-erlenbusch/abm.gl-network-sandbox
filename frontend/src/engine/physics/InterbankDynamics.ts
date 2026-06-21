// @ts-ignore
import { storage, float, Fn, If, uint, vec4, instanceIndex, Loop, uniform, MathNode } from 'three/tsl';
import { StorageInstancedBufferAttribute } from 'three/webgpu';

// Simulation Constants
export const MAX_BANKS = 2000; 
export const MAX_NEIGHBORS = 20;

export class InterbankDynamicsEngine {
    agentCount: number;

    financialStateRead: any; 
    financialStateWrite: any; 
    metadataStateRead: any;  
    metadataStateWrite: any;  
    
    neighborCounts: any;
    neighborMatrix: any;

    setupPass: any;
    simulationPass: any;
    copyPass: any;

    uniforms: {
        baseInterestRate: any;
        operatingCosts: any;
        interbankContagionRisk: any;
        customerDepositRate: any;
    };

    constructor(agentCount = MAX_BANKS) {
        this.agentCount = agentCount;

        this.uniforms = {
            baseInterestRate: uniform(0.05),
            operatingCosts: uniform(2.0),
            interbankContagionRisk: uniform(0.3),
            customerDepositRate: uniform(5.0)
        };

        this.financialStateRead = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        this.financialStateWrite = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        this.metadataStateRead = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        this.metadataStateWrite = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        
        this.neighborCounts = storage(new StorageInstancedBufferAttribute(new Uint32Array(agentCount), 1), 'uint', agentCount);
        this.neighborMatrix = storage(new StorageInstancedBufferAttribute(new Uint32Array(agentCount * MAX_NEIGHBORS), 1), 'uint', agentCount * MAX_NEIGHBORS);

        this.setupPass = Fn(() => {
            const i = instanceIndex;
            // Prevent compiler from optimizing out the buffers by copying initial data to the write buffer
            this.financialStateWrite.element(i).assign(this.financialStateRead.element(i));
            this.metadataStateWrite.element(i).assign(this.metadataStateRead.element(i));
        })().compute(this.agentCount);

        this.simulationPass = Fn(() => {
            const i = instanceIndex;
            
            // 1. Read start-of-tick state
            const meta = this.metadataStateRead.element(i);
            const fin = this.financialStateRead.element(i);
            
            const opCosts = meta.x.toVar();
            const velocityNW = meta.y.toVar();
            const isBankrupt = meta.z.toVar();
            const remotenessNW = meta.w.toVar();
            
            const assets = fin.x.toVar();
            const liabilities = fin.y.toVar();
            const nw = fin.z.toVar();
            const available = fin.w.toVar();
            
            If(isBankrupt.equal(0.0), () => {
                // --- FINANCIAL UPDATE LOGIC ---
                // Income from assets
                const income = assets.mul(this.uniforms.baseInterestRate);
                
                // Outlay for liabilities
                const outlay = liabilities.mul(this.uniforms.baseInterestRate).mul(0.8);
                
                // Operating costs
                opCosts.assign(1.0);
                If(nw.greaterThan(0.0), () => {
                    opCosts.assign(nw.mul(4.0));
                });
                
                // Customer deposits
                const deposits = this.uniforms.customerDepositRate;
                
                // Update available funds
                available.assign(available.add(income).sub(outlay).sub(opCosts).add(deposits));
                
                // New liabilities
                liabilities.assign(liabilities.add(deposits));
                
                // New assets from loans
                const newLoans = available.mul(0.5);
                assets.assign(assets.add(newLoans));
                available.assign(available.sub(newLoans));
                
                // Net worth
                const prevNW = nw.toVar();
                nw.assign(assets.sub(liabilities));
                
                // Velocity
                velocityNW.assign(nw.sub(prevNW));
                
                // Remoteness NW
                remotenessNW.assign(0.0);
                If(nw.lessThan(0.0), () => {
                    remotenessNW.assign(0.0);
                }).ElseIf(velocityNW.greaterThanEqual(-1.0), () => {
                    remotenessNW.assign(2147483647.0); 
                }).Else(() => {
                    remotenessNW.assign( nw.div(velocityNW.abs()).ceil() );
                });

                // --- CONTAGION LOGIC ---
                const myNeighborCount = this.neighborCounts.element(i);
                const contagionLoss = float(0.0).toVar();
                
                Loop({ start: uint(0), end: myNeighborCount, type: 'uint', condition: '<' }, ({ i: j }: any) => {
                    const neighborIdx = this.neighborMatrix.element(i.mul(MAX_NEIGHBORS).add(j));
                    
                    // Crucial: Always read neighbors' state from the deterministic Read buffer!
                    const nFin = this.financialStateRead.element(neighborIdx);
                    const nNW = nFin.z;
                    const nBankrupt = this.metadataStateRead.element(neighborIdx).z;
                    
                    If(nBankrupt.equal(0.0), () => {
                        If(nNW.lessThan(0.0), () => {
                            const hit = nNW.abs().mul(this.uniforms.interbankContagionRisk);
                            contagionLoss.addAssign(hit);
                        });
                    });
                });
                
                If(contagionLoss.greaterThan(0.0), () => {
                    assets.assign(assets.sub(contagionLoss));
                    nw.assign(assets.sub(liabilities));
                });

                // --- BANKRUPTCY LOGIC ---
                If(nw.lessThanEqual(0.0), () => {
                    isBankrupt.assign(1.0);
                    remotenessNW.assign(0.0);
                    assets.assign(0.0);
                    liabilities.assign(0.0);
                    nw.assign(0.0);
                    available.assign(0.0);
                });
            });

            // Write out the strictly calculated results for this tick to the Write buffers
            this.financialStateWrite.element(i).assign(vec4(assets, liabilities, nw, available));
            this.metadataStateWrite.element(i).assign(vec4(opCosts, velocityNW, isBankrupt, remotenessNW));
        })().compute(this.agentCount);

        this.copyPass = Fn(() => {
            const i = instanceIndex;
            // Ping-Pong the fully calculated tick back into the read buffers for the next frame
            this.financialStateRead.element(i).assign(this.financialStateWrite.element(i));
            this.metadataStateRead.element(i).assign(this.metadataStateWrite.element(i));
        })().compute(this.agentCount);
    }

    get passes() {
        return [this.simulationPass, this.copyPass];
    }
}
