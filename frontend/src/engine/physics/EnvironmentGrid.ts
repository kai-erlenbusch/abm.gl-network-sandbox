import { Fn, float, uint, int, instanceIndex, min, max, If, vec4, atomicLoad, atomicStore, select } from 'three/tsl';

export const environmentComputeNode = Fn(([
    homeDistReadAtomic, 
    homeDistWriteAtomic, 
    foodDistReadAtomic,
    foodDistWriteAtomic,
    evaporationRate, 
    diffusionRate,
    gridDimX, 
    gridDimY,
    gridSizeLimit,
    patchWallBuffer,
    isNetLogoModeUniform
]: any) => {
    const i = instanceIndex;
    
    If(i.lessThan(gridSizeLimit), () => {
        // "Evaporation" in distance-based pheromones means increasing the distance.
        // This ensures old paths slowly decay until they are forgotten (MAX_DIST).
        const maxDist = uint(10000000); // 10 million
        const isNetLogoMode = isNetLogoModeUniform.equal(1);
        
        If(isNetLogoMode, () => {
            // NetLogo Mode: foodDist is 'chemical'. Evaporates and diffuses.
            const centerChem = float(atomicLoad(foodDistReadAtomic.element(i)));
            
            // Calculate diffusion (read 8 neighbors)
            const col = uint(i).mod(uint(gridDimX));
            const row = uint(i).div(uint(gridDimX));
            
            const diffSum = float(0.0).toVar();
            const numNeighbors = float(0.0).toVar();
            
            // Quick neighbor offsets
            for (let dy = -1; dy <= 1; dy++) {
                for (let dx = -1; dx <= 1; dx++) {
                    if (dx === 0 && dy === 0) continue;
                    
                    const nx = int(col).add(dx);
                    const ny = int(row).add(dy);
                    
                    If(nx.greaterThanEqual(0).and(nx.lessThan(int(gridDimX))).and(ny.greaterThanEqual(0)).and(ny.lessThan(int(gridDimY))), () => {
                        const nIdx = uint(ny).mul(uint(gridDimX)).add(uint(nx));
                        diffSum.addAssign(float(atomicLoad(foodDistReadAtomic.element(nIdx))));
                        numNeighbors.addAssign(1.0);
                    });
                }
            }
            
            // diffuse chemical (diffusion-rate / 100)
            const diffRate = diffusionRate.div(100.0);
            const keepRate = float(1.0).sub(diffRate);
            
            // average neighbor chemical
            const avgNeighbor = select(numNeighbors.greaterThan(0.0), diffSum.div(numNeighbors), float(0.0));
            
            // New chemical after diffusion
            const diffusedChem = centerChem.mul(keepRate).add(avgNeighbor.mul(diffRate));
            
            // Evaporation
            // set chemical chemical * (100 - evaporation-rate) / 100
            const evapMultiplier = float(100.0).sub(evaporationRate).div(100.0);
            const finalChem = diffusedChem.mul(evapMultiplier);
            
            atomicStore(foodDistWriteAtomic.element(i), uint(finalChem));
            
            // homeDist is unused, just keep it maxDist
            atomicStore(homeDistWriteAtomic.element(i), maxDist);
            
        }).Else(() => {
            // Maze Mode: Distance fields DO NOT evaporate. 
            // Evaporating them destroys the shortest-path gradient.
            const currentHome = atomicLoad(homeDistReadAtomic.element(i));
            const currentFood = atomicLoad(foodDistReadAtomic.element(i));
            
            const isWall = patchWallBuffer.element(i).equal(1);
            
            If(isWall, () => {
                atomicStore(homeDistWriteAtomic.element(i), maxDist);
                atomicStore(foodDistWriteAtomic.element(i), maxDist);
            }).Else(() => {
                atomicStore(homeDistWriteAtomic.element(i), currentHome);
                
                // Evaporate foodDist: Add 3 per frame (180/sec). Cap at 30000.
                const decayedFood = min(currentFood.add(uint(3)), uint(30000));
                atomicStore(foodDistWriteAtomic.element(i), decayedFood);
            });
        });
    });
});

export const environmentSetupNode = Fn(([
    homeDistAAtomic, 
    homeDistBAtomic, 
    foodDistAAtomic,
    foodDistBAtomic,
    patchFoodBuffer,
    worldSizeUniform,
    cellSizeUniform,
    gridDimXUniform,
    gridDimYUniform,
    gridSizeLimit,
    seedUniform,
    isNetLogoModeUniform
]: any) => {
    const i = instanceIndex;
    
    If(i.lessThan(gridSizeLimit), () => {
        const maxDist = uint(10000000);
        const maxFoodDist = uint(30000);
        atomicStore(homeDistAAtomic.element(i), maxDist);
        atomicStore(homeDistBAtomic.element(i), maxDist);
        
        If(isNetLogoModeUniform.equal(1), () => {
            atomicStore(foodDistAAtomic.element(i), uint(0));
            atomicStore(foodDistBAtomic.element(i), uint(0));
        }).Else(() => {
            atomicStore(foodDistAAtomic.element(i), maxFoodDist);
            atomicStore(foodDistBAtomic.element(i), maxFoodDist);
        });
    });
});

export const trailComputeNode = Fn(([
    homeTrailReadAtomic, 
    homeTrailWriteAtomic, 
    foodTrailReadAtomic,
    foodTrailWriteAtomic,
    trailDimX, 
    trailDimY,
    trailSizeLimit
]: any) => {
    const i = instanceIndex;
    
    If(i.lessThan(trailSizeLimit), () => {
        // High-res visual trails. Evaporate and diffuse.
        const centerHome = float(atomicLoad(homeTrailReadAtomic.element(i)));
        const centerFood = float(atomicLoad(foodTrailReadAtomic.element(i)));
        
        // Calculate diffusion (read 8 neighbors)
        const col = uint(i).mod(uint(trailDimX));
        const row = uint(i).div(uint(trailDimX));
        
        const diffSumHome = float(0.0).toVar();
        const diffSumFood = float(0.0).toVar();
        const numNeighbors = float(0.0).toVar();
        
        for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx++) {
                if (dx === 0 && dy === 0) continue;
                
                const nx = int(col).add(dx);
                const ny = int(row).add(dy);
                
                If(nx.greaterThanEqual(0).and(nx.lessThan(int(trailDimX))).and(ny.greaterThanEqual(0)).and(ny.lessThan(int(trailDimY))), () => {
                    const nIdx = uint(ny).mul(uint(trailDimX)).add(uint(nx));
                    diffSumHome.addAssign(float(atomicLoad(homeTrailReadAtomic.element(nIdx))));
                    diffSumFood.addAssign(float(atomicLoad(foodTrailReadAtomic.element(nIdx))));
                    numNeighbors.addAssign(1.0);
                });
            }
        }
        
        // diffuse chemical (hardcoded trail visual rates: fast diffusion, fast decay)
        const diffRate = float(0.4); 
        const keepRate = float(1.0).sub(diffRate);
        
        // average neighbor chemical
        const avgNeighborHome = select(numNeighbors.greaterThan(0.0), diffSumHome.div(numNeighbors), float(0.0));
        const avgNeighborFood = select(numNeighbors.greaterThan(0.0), diffSumFood.div(numNeighbors), float(0.0));
        
        // New chemical after diffusion
        const diffusedHome = centerHome.mul(keepRate).add(avgNeighborHome.mul(diffRate));
        const diffusedFood = centerFood.mul(keepRate).add(avgNeighborFood.mul(diffRate));
        
        // Evaporation: scale down by 0.98 each frame
        const evapMultiplier = float(0.98);
        const finalHome = diffusedHome.mul(evapMultiplier);
        const finalFood = diffusedFood.mul(evapMultiplier);
        
        atomicStore(homeTrailWriteAtomic.element(i), uint(finalHome));
        atomicStore(foodTrailWriteAtomic.element(i), uint(finalFood));
    });
});

export const trailSetupNode = Fn(([
    homeTrailAAtomic, 
    homeTrailBAtomic, 
    foodTrailAAtomic,
    foodTrailBAtomic,
    trailSizeLimit
]: any) => {
    const i = instanceIndex;
    
    If(i.lessThan(trailSizeLimit), () => {
        atomicStore(homeTrailAAtomic.element(i), uint(0));
        atomicStore(homeTrailBAtomic.element(i), uint(0));
        atomicStore(foodTrailAAtomic.element(i), uint(0));
        atomicStore(foodTrailBAtomic.element(i), uint(0));
    });
});
