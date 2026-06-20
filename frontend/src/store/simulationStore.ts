import { create } from 'zustand';

export type MapType = 'open' | 'obstacle_diagonal' | 'obstacle_box' | 'obstacle_funnel' | 'obstacle_split' | `maze_${number}`;

export interface SimulationState {
  isPaused: boolean;
  setIsPaused: (val: boolean) => void;
  
  visualTrails: boolean;
  setVisualTrails: (val: boolean) => void;
  
  // Generic parameters mapped from UI
  dynamicParams: {
    model_speed?: number;
    agent_count?: number;
    world_size?: number;
    interaction_radius?: number;
    evaporation_rate?: number;
    diffusion_rate?: number;
    pheromone_drop_rate?: number;
  };
  setDynamicParam: (key: string, value: number) => void;

  // Setup trigger
  setupTrigger: number;
  triggerSetup: () => void;

  // Map configuration
  mapType: MapType;
  setMapType: (mapType: MapType) => void;
}

export const useSimulationStore = create<SimulationState>((set) => ({
  isPaused: false,
  setIsPaused: (val: boolean) => set({ isPaused: val }),
  
  visualTrails: true,
  setVisualTrails: (val: boolean) => set({ visualTrails: val }),
  
  dynamicParams: {
    model_speed: 1.0,
    agent_count: 125,
    world_size: 50.0,
    interaction_radius: 1.0,
    evaporation_rate: 0.1,
    diffusion_rate: 0.5,
    pheromone_drop_rate: 60.0,
  },
  setDynamicParam: (key: string, value: number) => 
    set((state) => ({ dynamicParams: { ...state.dynamicParams, [key]: value } })),
    
  setupTrigger: 0,
  triggerSetup: () => set((state) => ({ setupTrigger: state.setupTrigger + 1 })),

  mapType: 'open',
  setMapType: (mapType: MapType) => set({ mapType }),
}));
