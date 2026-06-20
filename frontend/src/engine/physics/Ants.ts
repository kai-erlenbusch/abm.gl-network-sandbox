import { Fn, uint, int, float, instanceIndex, vec2, If, clamp, floor, atomicAdd, atomicSub, atomicMin, distance, max, cos, sin, atomicLoad, atomicStore } from 'three/tsl';
import { prngHash } from '../math/PRNG';

// Helper to convert heading (radians) to vector
const headingToVec2 = (heading: any) => vec2(cos(heading), sin(heading));

export const antSetupNode = Fn(([positions, headings, stateBuffer, homeDists, foodDists, escapeSteps, totalDistances, seed, agentCountLimit, worldSize, nestPosUniform]: any) => {
    const i = instanceIndex;
    If(i.lessThan(agentCountLimit), () => {
        const uSeed = uint(seed.mul(10000.0));
        const base = uint(i).add(uSeed);
        
        const h1 = prngHash(base);
        
        // All ants start at the nest
        positions.element(i).assign(nestPosUniform);

        // Random initial heading [0, 2pi]
        headings.element(i).assign(h1.mul(Math.PI * 2.0));

        // State 0 = Foraging, State 1 = Returning
        stateBuffer.element(i).assign(uint(0));
        
        // Start distances
        homeDists.element(i).assign(uint(0));
        foodDists.element(i).assign(uint(10000000));
        escapeSteps.element(i).assign(uint(0));
        totalDistances.element(i).assign(float(0.0));
    });
});

const getPatchIdx = (pos: any, worldOffset: any, cellSize: any, gridDimX: any, gridDimY: any) => {
    const normX = pos.x.add(worldOffset);
    const normY = pos.y.add(worldOffset);
    const col = uint(clamp(floor(normX.div(cellSize)), float(0), float(gridDimX).sub(1.0)));
    const row = uint(clamp(floor(normY.div(cellSize)), float(0), float(gridDimY).sub(1.0)));
    return row.mul(uint(gridDimX)).add(col);
};

const getDistVal = (pos: any, bufferAtomic: any, patchWallBuffer: any, worldOffset: any, cellSize: any, gridDimX: any, gridDimY: any, isUphill: any) => {
    const idx = getPatchIdx(pos, worldOffset, cellSize, gridDimX, gridDimY);
    
    const isWall = patchWallBuffer.element(idx).equal(1);
    const val = atomicLoad(bufferAtomic.element(idx));
    
    const result = uint(0).toVar();
    If(isWall, () => {
        result.assign(isUphill ? uint(0) : uint(10000000));
    }).Else(() => {
        result.assign(val);
    });
    return result;
};

export const antBehaviorNode = Fn(([
    headings, 
    stateBuffer, 
    homeDists, 
    foodDists, 
    escapeSteps,
    totalDistances,
    homeDistAtomic,
    foodDistAtomic,
    positions, 
    timeUniform, 
    agentCountLimit, 
    deltaUniform, 
    worldOffsetUniform, 
    cellSizeUniform, 
    gridDimXUniform, 
    gridDimYUniform, 
    patchFoodBufferAtomic,
    worldSizeUniform,
    patchWallBuffer,
    nestPosUniform,
    isNetLogoModeUniform,
    pheromoneDropRateUniform,
    homeTrailAtomic,
    foodTrailAtomic,
    trailDimXUniform,
    trailDimYUniform
]: any) => {
    const i = instanceIndex;
    If(i.lessThan(agentCountLimit), () => {
        const pos = positions.element(i);
        const heading = headings.element(i);
        const state = stateBuffer.element(i);
        const homeDist = homeDists.element(i);
        const foodDist = foodDists.element(i);
        const escapeStep = escapeSteps.element(i);
        const totalDist = totalDistances.element(i);
        
        // Advance distances each tick
        homeDist.addAssign(uint(1));
        foodDist.addAssign(uint(1));
        
        const nestDist = distance(pos, nestPosUniform);
        const nestRadius = worldSizeUniform.mul(0.1);
        
        // Base random seed for this ant this frame
        const uSeed = uint(pos.x.mul(13.5).add(pos.y.mul(41.2)).add(timeUniform.mul(1000.0)).add(float(i)));
        
        const normX = pos.x.add(worldOffsetUniform);
        const normY = pos.y.add(worldOffsetUniform);
        const col = uint(clamp(floor(normX.div(cellSizeUniform)), float(0), float(gridDimXUniform).sub(1.0)));
        const row = uint(clamp(floor(normY.div(cellSizeUniform)), float(0), float(gridDimYUniform).sub(1.0)));
        const patchIdx = row.mul(uint(gridDimXUniform)).add(col);
        
        const speed = float(15.0);
        const tickRate = speed.div(cellSizeUniform); // NetLogo ticks per second
        const turnAmount = float(Math.PI / 4.0).mul(tickRate).mul(deltaUniform); // 45 degrees per tick
        
        If(state.equal(uint(0)), () => {
            // FORAGING (State 0)
            // ==================
            
            If(nestDist.lessThan(nestRadius), () => {
                homeDist.assign(uint(0));
            });
            
            const patchHomeDist = atomicLoad(homeDistAtomic.element(patchIdx));
            If(patchHomeDist.add(uint(1)).lessThan(homeDist), () => {
                homeDist.assign(patchHomeDist.add(uint(1)));
            }).Else(() => {
                atomicMin(homeDistAtomic.element(patchIdx), homeDist);
            });
            
            const patchFood = atomicAdd(patchFoodBufferAtomic.element(patchIdx), int(0));
            const pickedUp = int(0).toVar();

            If(patchFood.greaterThan(0), () => {
                // Try to claim food
                const oldFood = atomicSub(patchFoodBufferAtomic.element(patchIdx), int(1));
                If(oldFood.greaterThan(0), () => {
                    pickedUp.assign(1);
                    state.assign(1);
                    foodDist.assign(uint(0));
                    escapeStep.assign(uint(50));
                    heading.addAssign(Math.PI); // turn 180 degrees
                }).Else(() => {
                    atomicAdd(patchFoodBufferAtomic.element(patchIdx), int(1));
                });
            });

            If(pickedUp.equal(0), () => {
                // Sniff for food distance
                const sniffDist = cellSizeUniform.mul(1.0); 
                const fPos = pos.add(headingToVec2(heading).mul(sniffDist));
                const lPos = pos.add(headingToVec2(heading.add(Math.PI / 4.0)).mul(sniffDist));
                const rPos = pos.add(headingToVec2(heading.sub(Math.PI / 4.0)).mul(sniffDist));
                
                const isNetLogoMode = isNetLogoModeUniform.equal(1);
                
                If(isNetLogoMode, () => {
                    // NETLOGO OPEN WORLD MODE
                    // Steer toward chemical if it's between 0.05 and 2 (scaled by 1000: 50 to 2000)
                    const minChem = uint(50);
                    const maxChem = uint(2000);
                    
                    const ff = atomicLoad(foodDistAtomic.element(getPatchIdx(fPos, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform)));
                    const lf = atomicLoad(foodDistAtomic.element(getPatchIdx(lPos, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform)));
                    const rf = atomicLoad(foodDistAtomic.element(getPatchIdx(rPos, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform)));
                    
                    const ffValid = ff.greaterThanEqual(minChem).and(ff.lessThan(maxChem));
                    const lfValid = lf.greaterThanEqual(minChem).and(lf.lessThan(maxChem));
                    const rfValid = rf.greaterThanEqual(minChem).and(rf.lessThan(maxChem));
                    
                    If(ffValid.or(lfValid).or(rfValid), () => {
                        // Uphill chemical (choose the largest)
                        If(rf.greaterThan(ff).or(lf.greaterThan(ff)), () => {
                            If(rf.greaterThan(lf), () => {
                                heading.subAssign(turnAmount); // rt 45
                            }).Else(() => {
                                heading.addAssign(turnAmount); // lt 45
                            });
                        });
                    });
                }).Else(() => {
                    // MAZE MODE
                    const maxDist = uint(30000);
                    
                    const ff = getDistVal(fPos, foodDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(0));
                    const lf = getDistVal(lPos, foodDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(0));
                    const rf = getDistVal(rPos, foodDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(0));
                    
                    const patchFoodDist = atomicLoad(foodDistAtomic.element(patchIdx));
                    If(patchFoodDist.lessThan(maxDist), () => {
                        If(ff.greaterThanEqual(patchFoodDist).and(lf.greaterThanEqual(patchFoodDist)).and(rf.greaterThanEqual(patchFoodDist)), () => {
                            // Dead end of a trail (food is gone or trail broke). Erase it!
                            atomicStore(foodDistAtomic.element(patchIdx), maxDist);
                            heading.addAssign(Math.PI); // Turn around to unzip the trail backward
                        });
                    });
                    
                    If(ff.lessThan(maxDist).or(lf.lessThan(maxDist)).or(rf.lessThan(maxDist)), () => {
                        // Smell food! Steer DOWNHILL
                        If(rf.lessThan(ff).or(lf.lessThan(ff)), () => {
                            If(rf.lessThan(lf), () => {
                                heading.subAssign(turnAmount); // rt 45
                            }).Else(() => {
                                heading.addAssign(turnAmount); // lt 45
                            });
                        });
                    }).Else(() => {
                        // No food smell. Steer UPHILL away from home to explore
                        const fh = getDistVal(fPos, homeDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(1));
                        const lh = getDistVal(lPos, homeDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(1));
                        const rh = getDistVal(rPos, homeDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(1));
                        
                        If(rh.greaterThan(fh).or(lh.greaterThan(fh)), () => {
                            If(rh.greaterThan(lh), () => {
                                heading.subAssign(turnAmount); // rt 45
                            }).Else(() => {
                                heading.addAssign(turnAmount); // lt 45
                            });
                        });
                    });
                });
            });
        }).Else(() => {
            // ==================
            // RETURNING (State 1)
            // ==================
            If(nestDist.lessThan(nestRadius), () => {
                // Drop food
                state.assign(0);
                homeDist.assign(uint(0));
                heading.addAssign(Math.PI); // turn 180 degrees
            }).Else(() => {
                const isNetLogoMode = isNetLogoModeUniform.equal(1);
                
                If(isNetLogoMode, () => {
                    // NETLOGO OPEN WORLD MODE
                    // Drop chemical
                    const dropAmount = uint(pheromoneDropRateUniform.mul(1000.0));
                    atomicAdd(foodDistAtomic.element(patchIdx), dropAmount);
                    
                    // Steer toward nest (uphill nest-scent = downhill distance)
                    const sniffDist = cellSizeUniform.mul(1.0); 
                    const fPos = pos.add(headingToVec2(heading).mul(sniffDist));
                    const lPos = pos.add(headingToVec2(heading.add(Math.PI / 4.0)).mul(sniffDist)); 
                    const rPos = pos.add(headingToVec2(heading.sub(Math.PI / 4.0)).mul(sniffDist));
                    
                    const fd = distance(fPos, nestPosUniform);
                    const ld = distance(lPos, nestPosUniform);
                    const rd = distance(rPos, nestPosUniform);
                    
                    If(rd.lessThan(fd).or(ld.lessThan(fd)), () => {
                        If(rd.lessThan(ld), () => {
                            heading.subAssign(turnAmount); // rt 45
                        }).Else(() => {
                            heading.addAssign(turnAmount); // lt 45
                        });
                    });
                }).Else(() => {
                    // MAZE MODE
                    const patchFoodDist = atomicLoad(foodDistAtomic.element(patchIdx));
                    If(patchFoodDist.add(uint(10)).lessThan(foodDist), () => {
                        foodDist.assign(patchFoodDist.add(uint(10)));
                    }).Else(() => {
                        atomicMin(foodDistAtomic.element(patchIdx), foodDist);
                    });
                    
                    const sniffDist = cellSizeUniform.mul(1.0); 
                    const fPos = pos.add(headingToVec2(heading).mul(sniffDist));
                    const lPos = pos.add(headingToVec2(heading.add(Math.PI / 4.0)).mul(sniffDist)); 
                    const rPos = pos.add(headingToVec2(heading.sub(Math.PI / 4.0)).mul(sniffDist)); 
                        
                        const fh = getDistVal(fPos, homeDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(0));
                        const lh = getDistVal(lPos, homeDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(0));
                        const rh = getDistVal(rPos, homeDistAtomic, patchWallBuffer, worldOffsetUniform, cellSizeUniform, gridDimXUniform, gridDimYUniform, uint(0));
                        
                        const maxDist = uint(10000000);
                        If(fh.lessThan(maxDist).or(lh.lessThan(maxDist)).or(rh.lessThan(maxDist)), () => {
                            If(rh.lessThan(fh).or(lh.lessThan(fh)), () => {
                                If(rh.lessThan(lh), () => {
                                    heading.subAssign(turnAmount); // rt 45
                                }).Else(() => {
                                    heading.addAssign(turnAmount); // lt 45
                                });
                            });
                        });
                    });
                });
            });
        
        // Wiggle
        const randNum = prngHash(uSeed); // returns 0.0 to 1.0
        const maxWiggle = float(39.0 / 180.0 * Math.PI); // 39 degrees
        const wiggleAmount = randNum.sub(0.5).mul(2.0).mul(maxWiggle).mul(tickRate).mul(deltaUniform);
        heading.addAssign(wiggleAmount);
        
        // Move Forward
        const velocity = headingToVec2(heading).mul(speed).mul(deltaUniform);
        const nextPos = pos.add(velocity);
        
        const isOutOfBounds = nextPos.x.greaterThan(worldOffsetUniform)
            .or(nextPos.x.lessThan(worldOffsetUniform.mul(-1.0)))
            .or(nextPos.y.greaterThan(worldOffsetUniform))
            .or(nextPos.y.lessThan(worldOffsetUniform.mul(-1.0)));
            
        If(isOutOfBounds, () => {
            heading.addAssign(Math.PI / 4.0);
        }).Else(() => {
            const collisionLookahead = float(0.6); // Offset check by roughly half the ant's visual length
            const checkPos = nextPos.add(headingToVec2(heading).mul(collisionLookahead));
            
            const nextNormX = checkPos.x.add(worldOffsetUniform);
            const nextNormY = checkPos.y.add(worldOffsetUniform);
            const nextCol = uint(clamp(floor(nextNormX.div(cellSizeUniform)), float(0), float(gridDimXUniform).sub(1.0)));
            const nextRow = uint(clamp(floor(nextNormY.div(cellSizeUniform)), float(0), float(gridDimYUniform).sub(1.0)));
            const nextPatchIdx = nextRow.mul(uint(gridDimXUniform)).add(nextCol);
            
            const isWall = patchWallBuffer.element(nextPatchIdx).equal(1);
            
            If(isWall, () => {
                const isLeftFollower = instanceIndex.mod(2).equal(0);
                If(isLeftFollower, () => {
                    heading.addAssign(Math.PI / 4.0);
                }).Else(() => {
                    heading.subAssign(Math.PI / 4.0);
                });
            }).Else(() => {
                pos.assign(nextPos);
                totalDist.addAssign(speed.mul(deltaUniform));
            });
        });
        
        // --- VISUAL TRAILS EMISSION ---
        const trailCol = uint(clamp(floor((pos.x.add(worldSizeUniform.div(2.0))).div(worldSizeUniform).mul(trailDimXUniform)), float(0.0), trailDimXUniform.sub(1.0)));
        const trailRow = uint(clamp(floor((pos.y.add(worldSizeUniform.div(2.0))).div(worldSizeUniform).mul(trailDimYUniform)), float(0.0), trailDimYUniform.sub(1.0)));
        const trailIdx = trailRow.mul(uint(trailDimXUniform)).add(trailCol);
        
        const trailEmission = uint(pheromoneDropRateUniform.mul(200.0));
        If(state.equal(uint(1)), () => {
            atomicAdd(foodTrailAtomic.element(trailIdx), trailEmission);
        }).Else(() => {
            atomicAdd(homeTrailAtomic.element(trailIdx), trailEmission);
        });
    });
});
