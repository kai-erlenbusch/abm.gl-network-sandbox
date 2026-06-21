// @ts-ignore
import { storage, float, Fn, If, uint, vec4, instanceIndex, Loop, uniform, MathNode } from 'three/tsl';
import { StorageInstancedBufferAttribute } from 'three/webgpu';

// Simulation Constants
export const MAX_BANKS = 2000; 
export const MAX_NEIGHBORS = 20;

export class InterbankDynamicsEngine {
    agentCount: number;

    financialState: any; // vec4(Assets, Liabilities, NetWorth, AvailableFunds)
    metadataState: any;  // vec4(OperatingCosts, VelocityNW, IsBankrupt, Padding)
    
    neighborCounts: any;
    neighborMatrix: any;

    setupPass: any;
    financialUpdatePass: any;
    interbankContagionPass: any;
    bankruptcyPass: any;

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

        this.financialState = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        this.metadataState = storage(new StorageInstancedBufferAttribute(new Float32Array(agentCount * 4), 4), 'vec4', agentCount);
        
        this.neighborCounts = storage(new StorageInstancedBufferAttribute(new Uint32Array(agentCount), 1), 'uint', agentCount);
        this.neighborMatrix = storage(new StorageInstancedBufferAttribute(new Uint32Array(agentCount * MAX_NEIGHBORS), 1), 'uint', agentCount * MAX_NEIGHBORS);

        this.setupPass = Fn(() => {
            const i = instanceIndex;
            // Force buffer creation on GPU so readback doesn't fail when paused
            this.financialState.element(i).assign(this.financialState.element(i));
            this.metadataState.element(i).assign(this.metadataState.element(i));
        })().compute(this.agentCount);

        this.financialUpdatePass = Fn(() => {
            const i = instanceIndex;
            
            const meta = this.metadataState.element(i);
            const isBankrupt = meta.z;
            
            If(isBankrupt.equal(0.0), () => {
                const fin = this.financialState.element(i);
                const assets = fin.x;
                const liabilities = fin.y;
                let nw = fin.z;
                let available = fin.w;
                
                // Income from assets
                const income = assets.mul(this.uniforms.baseInterestRate);
                
                // Outlay for liabilities
                const outlay = liabilities.mul(this.uniforms.baseInterestRate).mul(0.8); // pay slightly less than we earn on assets
                
                // Operating costs: C# Logic => NW > 0 ? 4*NW : 1
                const opCosts = float(1.0).toVar();
                If(nw.greaterThan(0.0), () => {
                    opCosts.assign(nw.mul(4.0));
                });
                
                // Customer deposits (simplified continuous flow)
                const deposits = this.uniforms.customerDepositRate;
                
                // Update available funds
                available = available.add(income).sub(outlay).sub(opCosts).add(deposits);
                
                // New liabilities from new deposits
                const newLiabilities = liabilities.add(deposits);
                
                // New assets from loans
                const newLoans = available.mul(0.5);
                const newAssets = assets.add(newLoans);
                available = available.sub(newLoans);
                
                // Net worth = Assets - Liabilities
                nw = newAssets.sub(newLiabilities);
                
                // Velocity
                const prevNW = fin.z;
                const velocityNW = nw.sub(prevNW);
                
                // Remoteness NW
                const remotenessNW = float(0.0).toVar();
                If(nw.lessThan(0.0), () => {
                    remotenessNW.assign(0.0);
                }).ElseIf(velocityNW.greaterThanEqual(-1.0), () => {
                    remotenessNW.assign(2147483647.0); // max value approx
                }).Else(() => {
                    remotenessNW.assign( nw.div(velocityNW.abs()).ceil() );
                });
                
                this.financialState.element(i).assign(vec4(newAssets, newLiabilities, nw, available));
                this.metadataState.element(i).assign(vec4(opCosts, velocityNW, 0.0, remotenessNW));
            });
        })().compute(this.agentCount);

        this.interbankContagionPass = Fn(() => {
            const i = instanceIndex;
            const meta = this.metadataState.element(i);
            const isBankrupt = meta.z;
            
            If(isBankrupt.equal(0.0), () => {
                const fin = this.financialState.element(i);
                const myNW = fin.z;
                let myAssets = fin.x;
                
                const myNeighborCount = this.neighborCounts.element(i);
                
                // Contagion: if neighbors are struggling (NW < 0), they drag me down (I lose assets)
                const contagionLoss = float(0.0).toVar();
                
                Loop({ start: uint(0), end: myNeighborCount, type: 'uint', condition: '<' }, ({ i: j }) => {
                    const neighborIdx = this.neighborMatrix.element(i.mul(MAX_NEIGHBORS).add(j));
                    const nFin = this.financialState.element(neighborIdx);
                    const nNW = nFin.z;
                    const nBankrupt = this.metadataState.element(neighborIdx).z;
                    
                    If(nBankrupt.equal(0.0), () => {
                        If(nNW.lessThan(0.0), () => {
                            // Neighbor is insolvent but not yet officially bankrupt.
                            // We take a hit proportional to contagion risk.
                            const hit = nNW.abs().mul(this.uniforms.interbankContagionRisk);
                            contagionLoss.addAssign(hit);
                        });
                    });
                });
                
                If(contagionLoss.greaterThan(0.0), () => {
                    myAssets = myAssets.sub(contagionLoss);
                    const newNW = myAssets.sub(fin.y);
                    this.financialState.element(i).assign(vec4(myAssets, fin.y, newNW, fin.w));
                });
            });
        })().compute(this.agentCount);

        this.bankruptcyPass = Fn(() => {
            const i = instanceIndex;
            const meta = this.metadataState.element(i);
            const isBankrupt = meta.z;
            
            If(isBankrupt.equal(0.0), () => {
                const fin = this.financialState.element(i);
                const nw = fin.z;
                
                If(nw.lessThanEqual(0.0), () => {
                    // Mark as bankrupt
                    this.metadataState.element(i).assign(vec4(meta.x, meta.y, 1.0, 0.0));
                    // Wipe financial state
                    this.financialState.element(i).assign(vec4(0.0, 0.0, 0.0, 0.0));
                });
            });
        })().compute(this.agentCount);
    }

    get passes() {
        return [this.financialUpdatePass, this.interbankContagionPass, this.bankruptcyPass];
    }
}
