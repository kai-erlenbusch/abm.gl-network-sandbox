# abm.gl Network Sandbox

This repository is a dedicated sandbox for network-based agent experimentation within the broader `abm.gl` ecosystem. It leverages GPU-accelerated computing to simulate epidemiological virus dynamics across a force-directed graph architecture.

## Overview

Unlike the primary `abm.gl` framework which focuses on massive-scale spatial ABMs using Three.js WebGPU compute shaders, this sandbox is specifically tuned for **Network Theory** and **Graph-Based Simulations**. 

### The Model: Virus on a Network

This sandbox implements a high-performance GPU-accelerated version of the classic [NetLogo "Virus on a Network" model](https://ccl.northwestern.edu/netlogo/models/VirusonaNetwork). 

![abm.gl Epidemic Virus Screenshot](screenshot.png)

This model demonstrates the spread of a virus through a network (e.g. modeling the progress of a computer virus/worm). Each node represents an entity (like a computer) and can be in one of three states:
- **Susceptible (Blue)**: Healthy but vulnerable.
- **Infected (Red)**: Currently carrying and spreading the virus.
- **Resistant (Gray)**: Immune to the virus (e.g. patched with antivirus).

**How it works:**
Each time step (tick), each infected node (colored red) attempts to infect all of its neighbors. Susceptible neighbors (colored blue) will be infected with a probability given by the VIRUS-SPREAD-CHANCE slider. This might correspond to the probability that someone on the susceptible system actually executes the infected email attachment. Resistant nodes (colored gray) cannot be infected. This might correspond to up-to-date antivirus software and security patches that make a computer immune to this particular virus.

Infected nodes are not immediately aware that they are infected. Only every so often (determined by the VIRUS-CHECK-FREQUENCY slider) do the nodes check whether they are infected by a virus. This might correspond to a regularly scheduled virus-scan procedure, or simply a human noticing something fishy about how the computer is behaving. When the virus has been detected, there is a probability that the virus will be removed (determined by the RECOVERY-CHANCE slider).

If a node does recover, there is some probability that it will become resistant to this virus in the future (given by the GAIN-RESISTANCE-CHANCE slider).

When a node becomes resistant, the links between it and its neighbors are darkened, since they are no longer possible vectors for spreading the virus.

### Key Technologies
- **Rendering**: `@cosmos.gl/graph` for ultra-fast 2D WebGL graph rendering.
- **Physics Engine**: Custom WebGPU compute shaders (`VirusDynamics.ts`) that calculate network forces, bounding collisions, and infection state transitions directly on the GPU.
- **Telemetry**: `@chartgpu/chartgpu` and `chartgpu-react` for blazing-fast 60FPS streaming telemetry (tracking Susceptible, Infected, and Resistant populations).
- **State Management**: `zustand` for high-performance reactive UI state without triggering massive React re-renders.
- **UI Framework**: Next.js App Router and TailwindCSS for a sleek, glass-morphism dashboard.

## Simulation Features
- **GPU-Accelerated SIR Model**: Simulates Susceptible, Infected, and Resistant states.
- **Force-Directed Graph**: Nodes repel each other while links act as springs.
- **Real-Time HUD**: Tracks ticks, exact simulation time (HH:MM:SS), and browser FPS.
- **Dynamic Controls**: Instantly tweak parameters like Infection Radius, Recovery Probability, Force Strength, and Friction.

## Setup & Running
```bash
cd frontend
npm install
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) to view the simulation.

## Architecture Highlights
- **Custom StrictMode Bypasses**: The telemetry chart utilizes manual buffer management and array truncation to completely sidestep React 18 Strict Mode double-mounting memory leaks.

## Changelog & Recent Updates
- **Algorithmic Gaussian Clustering:** Replaced the unstable WebGL force-directed layout engine with a pure-JavaScript algorithmic clustering generator. This prevents WebGL texture memory crashes on certain hardware and browser configurations when rendering massive (50k+) node networks.
- **Organic Hub Generation:** The network generator now creates distinct "City Hubs" with a Gaussian distribution, making massive networks readable and visually striking rather than appearing as uniform noise.
- **Community Edge Wiring:** Edges are now generated using an 85/15 ratio (85% intra-community connections within the same hub, and 15% global "highway" connections), perfectly simulating dense population centers connected by travel routes.
- **Dynamic Node Scaling:** Point sizes dynamically scale down based on the population `N`, allowing distinct nodes to remain visible without merging into solid blocks of color.
- **Simulation State Fixes:** Fixed WebGPU buffer state transition bugs where nodes were failing to transition to the "Resistant" state correctly after recovery.

## Citations & Licensing

This project is a high-performance GPU re-implementation inspired by the NetLogo models library, this model is from the following original authors:

**For the model itself:**
> Stonedahl, F. and Wilensky, U. (2008). NetLogo Virus on a Network model. http://ccl.northwestern.edu/netlogo/models/VirusonaNetwork. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

**For the NetLogo software:**
> Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
