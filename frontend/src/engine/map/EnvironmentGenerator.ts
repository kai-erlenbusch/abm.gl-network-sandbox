

export type MapType = 'open' | 'obstacle_diagonal' | 'obstacle_box' | 'obstacle_funnel' | 'obstacle_split' | `maze_${number}`;

export function generateEnvironmentMap(
    mapType: MapType,
    gridDimX: number,
    gridDimY: number,
    wallBuffer: Int32Array,
    foodBuffer: Int32Array,
    seed: number = 0
) {
    // 1. Clear buffers
    for (let i = 0; i < gridDimX * gridDimY; i++) {
        wallBuffer[i] = 0;
        foodBuffer[i] = 0;
    }
    
    const setWall = (x: number, y: number) => {
        if (x >= 0 && x < gridDimX && y >= 0 && y < gridDimY) {
            wallBuffer[y * gridDimX + x] = 1;
        }
    };

    const setFood = (x: number, y: number, amount: number) => {
        if (x >= 0 && x < gridDimX && y >= 0 && y < gridDimY) {
            foodBuffer[y * gridDimX + x] = amount;
        }
    };

    const cx = Math.floor(gridDimX / 2);
    const cy = Math.floor(gridDimY / 2);

    if (mapType === 'open') {
        // Default food placement (4 clusters around the center)
        const offset = Math.floor(gridDimX * 0.4);
        const radius = Math.floor(gridDimX * 0.08);
        const centers = [
            { x: cx + offset, y: cy + offset },
            { x: cx + offset, y: cy - offset },
            { x: cx - offset, y: cy + offset },
            { x: cx - offset, y: cy - offset },
        ];
        
        for (let y = 0; y < gridDimY; y++) {
            for (let x = 0; x < gridDimX; x++) {
                for (const c of centers) {
                    if (Math.hypot(x - c.x, y - c.y) < radius) {
                        setFood(x, y, 1);
                    }
                }
            }
        }
    } 
    else if (mapType === 'obstacle_diagonal') {
        // Diagonal Wall
        for (let i = -40; i < 40; i++) {
            for (let w = -2; w <= 2; w++) {
                setWall(cx + i + w, cy - i);
            }
        }
        // Place food in corners
        for (let y = 0; y < gridDimY; y++) {
            for (let x = 0; x < gridDimX; x++) {
                if (Math.hypot(x - (cx + 40), y - (cy - 40)) < 10) setFood(x, y, 2);
                if (Math.hypot(x - (cx - 40), y - (cy + 40)) < 10) setFood(x, y, 2);
            }
        }
    }
    else if (mapType === 'obstacle_box') {
        // Center Box
        for (let y = cy - 20; y <= cy + 20; y++) {
            for (let x = cx - 20; x <= cx + 20; x++) {
                if (Math.abs(x - cx) > 15 || Math.abs(y - cy) > 15) {
                    setWall(x, y);
                }
            }
        }
        // Openings
        for (let x = cx - 5; x <= cx + 5; x++) {
            wallBuffer[(cy - 20) * gridDimX + x] = 0;
            wallBuffer[(cy + 20) * gridDimX + x] = 0;
        }
        for (let y = 0; y < gridDimY; y++) {
            for (let x = 0; x < gridDimX; x++) {
                if (Math.hypot(x - cx, y - (cy - 40)) < 8) setFood(x, y, 1);
                if (Math.hypot(x - cx, y - (cy + 40)) < 8) setFood(x, y, 1);
            }
        }
    }
    else if (mapType === 'obstacle_funnel') {
        // Funnel
        for (let x = 0; x < gridDimX; x++) {
            const yOffset = Math.abs(x - cx);
            if (yOffset > 10) {
                setWall(x, cy - 2);
                setWall(x, cy - 1);
                setWall(x, cy);
                setWall(x, cy + 1);
                setWall(x, cy + 2);
            }
        }
        for (let y = 0; y < gridDimY; y++) {
            for (let x = 0; x < gridDimX; x++) {
                if (Math.hypot(x - cx, y - (cy + 40)) < 10) setFood(x, y, 2);
            }
        }
    }
    else if (mapType === 'obstacle_split') {
        // Split Paths
        for (let y = cy - 30; y <= cy + 30; y++) {
            setWall(cx - 2, y);
            setWall(cx - 1, y);
            setWall(cx, y);
            setWall(cx + 1, y);
            setWall(cx + 2, y);
        }
        for (let y = 0; y < gridDimY; y++) {
            for (let x = 0; x < gridDimX; x++) {
                if (Math.hypot(x - cx, y - (cy + 45)) < 10) setFood(x, y, 1);
            }
        }
    }
    else if (mapType.startsWith('maze_')) {
        const mazeSeed = parseInt(mapType.split('_')[1] || '1');
        
        // We'll generate a smaller logical maze and scale it up so paths are wide
        const scale = 4;
        const mDimX = 15; // 15x15 logical cells
        const mDimY = 15;
        const lWidth = mDimX * 2 + 1; // 31
        const lHeight = mDimY * 2 + 1; // 31
        
        const logicalWalls = new Int32Array(lWidth * lHeight);
        for (let i = 0; i < logicalWalls.length; i++) logicalWalls[i] = 1;
        
        const unvisited = new Set<number>();
        for (let y = 0; y < mDimY; y++) {
            for (let x = 0; x < mDimX; x++) {
                unvisited.add(y * mDimX + x);
            }
        }
        
        const stack: number[] = [];
        let current = 0;
        unvisited.delete(current);
        stack.push(current);
        
        // Simple 32-bit PRNG for CPU map generation
        const _prng = (a: number) => {
            let t = a += 0x6D2B79F5;
            t = Math.imul(t ^ t >>> 15, t | 1);
            t ^= t + Math.imul(t ^ t >>> 7, t | 61);
            return ((t ^ t >>> 14) >>> 0) / 4294967296;
        };
        
        let step = 0;
        
        while (stack.length > 0) {
            const cx = current % mDimX;
            const cy = Math.floor(current / mDimX);
            
            const wx = cx * 2 + 1;
            const wy = cy * 2 + 1;
            logicalWalls[wy * lWidth + wx] = 0;
            
            const neighbors: {nx: number, ny: number, dir: number}[] = [];
            if (cy > 0 && unvisited.has((cy - 1) * mDimX + cx)) neighbors.push({nx: cx, ny: cy - 1, dir: 0});
            if (cy < mDimY - 1 && unvisited.has((cy + 1) * mDimX + cx)) neighbors.push({nx: cx, ny: cy + 1, dir: 1});
            if (cx > 0 && unvisited.has(cy * mDimX + (cx - 1))) neighbors.push({nx: cx - 1, ny: cy, dir: 2});
            if (cx < mDimX - 1 && unvisited.has(cy * mDimX + (cx + 1))) neighbors.push({nx: cx + 1, ny: cy, dir: 3});
            
            if (neighbors.length > 0) {
                const rand = _prng(mazeSeed * 10000 + step++);
                const safeRand = isNaN(rand) ? 0 : rand;
                const nextIndex = Math.floor(safeRand * neighbors.length) % neighbors.length;
                const next = neighbors[nextIndex];
                
                const wallX = wx + (next.nx - cx);
                const wallY = wy + (next.ny - cy);
                logicalWalls[wallY * lWidth + wallX] = 0;
                
                current = next.ny * mDimX + next.nx;
                unvisited.delete(current);
                stack.push(current);
            } else {
                current = stack.pop()!;
            }
        }
        
        // Scale logical maze into real wallBuffer
        for (let i = 0; i < gridDimX * gridDimY; i++) wallBuffer[i] = 1;
        
        const offsetX = Math.floor((gridDimX - lWidth * scale) / 2);
        const offsetY = Math.floor((gridDimY - lHeight * scale) / 2);
        
        for (let y = 0; y < lHeight; y++) {
            for (let x = 0; x < lWidth; x++) {
                if (logicalWalls[y * lWidth + x] === 0) {
                    for (let dy = 0; dy < scale; dy++) {
                        for (let dx = 0; dx < scale; dx++) {
                            const gx = offsetX + x * scale + dx;
                            const gy = offsetY + y * scale + dy;
                            if (gx >= 0 && gx < gridDimX && gy >= 0 && gy < gridDimY) {
                                wallBuffer[gy * gridDimX + gx] = 0;
                            }
                        }
                    }
                }
            }
        }
        
        // Clear nest area (Bottom Right: center ~ 118, 10)
        for (let y = 0; y < gridDimY; y++) {
            for (let x = 0; x < gridDimX; x++) {
                if (Math.hypot(x - 118, y - 10) < 14) {
                    if (x > 1 && x < gridDimX - 2 && y > 1 && y < gridDimY - 2) {
                        wallBuffer[y * gridDimX + x] = 0;
                    }
                }
            }
        }
        
        // Place Food in Top Left (center ~ 10, 118)
        for (let y = 0; y < gridDimY; y++) {
            for (let x = 0; x < gridDimX; x++) {
                if (Math.hypot(x - 10, y - 118) < 14) {
                    if (x > 1 && x < gridDimX - 2 && y > 1 && y < gridDimY - 2) {
                        wallBuffer[y * gridDimX + x] = 0;
                    }
                    if (Math.hypot(x - 10, y - 118) < 6) {
                        setFood(x, y, 2);
                    }
                }
            }
        }
    }
}
