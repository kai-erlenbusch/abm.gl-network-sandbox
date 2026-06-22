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
    number_of_nodes?: number;
    average_node_degree?: number;
    initial_outbreak_size?: number;
    virus_spread_chance?: number;
    virus_check_frequency?: number;
    recovery_chance?: number;
    gain_resistance_chance?: number;
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
    number_of_nodes: 150,
    average_node_degree: 6,
    initial_outbreak_size: 3,
    virus_spread_chance: 2.5,
    virus_check_frequency: 1.0,
    recovery_chance: 5.0,
    gain_resistance_chance: 5.0,
  },
  setDynamicParam: (key: string, value: number) => 
    set((state) => ({ dynamicParams: { ...state.dynamicParams, [key]: value } })),
    
  setupTrigger: 0,
  triggerSetup: () => set((state) => ({ setupTrigger: state.setupTrigger + 1 })),

  mapType: 'open',
  setMapType: (mapType: MapType) => set({ mapType }),
}));
