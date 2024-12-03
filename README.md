```
    __  ____                 __  __               __                                         
   /  |/  (_)_____________  / / / /___ __________/ /                                         
  / /|_/ / / ___/ ___/ __ \/ /_/ / __ `/ ___/ __  /                                          
 / /  / / / /__/ /  / /_/ / __  / /_/ / /  / /_/ /                                           
/_/  /_/_/\___/_/_  \____/_/ /_/\__,_/_/___\__,_/             __      __                _  __
        / ____/ (_)___ _/ /_  / /_   / ___/(_)___ ___  __  __/ /___ _/ /_____  _____   | |/ /
       / /_  / / / __ `/ __ \/ __/   \__ \/ / __ `__ \/ / / / / __ `/ __/ __ \/ ___/   |   / 
      / __/ / / / /_/ / / / / /_    ___/ / / / / / / / /_/ / / /_/ / /_/ /_/ / /      /   |  
     /_/   /_/_/\__, /_/ /_/\__/   /____/_/_/ /_/ /_/\__,_/_/\__,_/\__/\____/_/      /_/|_|  
               /____/
```
# What is MicroHard Flight Simulator X?
MicroHard Flight Simulator X is a student project in the course TDT4295 Computer Design Project at NTNU with the goal of designing, programming and developing a custom 3D fligt simulator utilizing a self designed PCB sporting a Xilinx Artix 
A100T FPGA and a SiliconLabs EFM32 MCU. The system outlined here is the graphics processing system residing on the FPGA, and deals with all the graphical processing and effects needed to visualize the flight simulator. This part of the project is the culmination of a few months worth of hard work by Morten sørensen and Andreas V. Jonsterhaug. The system is written in SystemVerilog with Verilator testbenches for each module in the system. The other parts of the system, that is the PCB and the MCU source code can be found elsewhere in the MH Flight Simulator X org: ![GitHub Page](https://github.com/MH-Flight-Simulator-X)

<div align="center">
  <img src="https://github.com/MH-Flight-Simulator-X/FPGA-src/blob/main/imgs/flight_sim.png" alt="Cool photo" width="600"/>
</div>

## Overview 
The project is splitt into multiple modules and accompanying documentation in **Documentation/**.

A figure showing the top-level design overview:
![System Overview](https://github.com/MH-Flight-Simulator-X/System-Figures-And-Microarchitecture/blob/main/System/system-System%20Arcitecture%20Overview.png)

And here is a bad drawing of the architecture:
<div align="center">
  <img src="https://github.com/MH-Flight-Simulator-X/System-Figures-And-Microarchitecture/blob/main/System/architecture.jpg" alt="Drawing Architecture" height="800"/>
</div>

The following is an overview of the project structure  
<pre>
<strong>FPGA-src</strong>
├── src/  
│   └── top_mh_flight_sim_fpga.sv  
├── lib/  
│   ├── Clock/  
|   |   ├── clock_100Mhz.sv
│   │   └── clock_480p.sv
│   ├── Display/  
│   │   └── display_480p
│   ├── MCU-FPGA-Com/
│   ├── Math/  
|   |   ├── FastInverse/
|   |   ├── FixedPointDivide/
|   |   ├── MatMul/
│   │   └── MatVecMul/
│   ├── Memory/  
|   |   ├── BRAM_DP/
|   |   ├── BRAM_SP/
|   |   ├── Buffer/
|   |   ├── FIFO/
|   |   ├── G-Buffer/
│   │   └── ROM/
│   ├── Display/  
│   │   └── display_480p.sv  
│   ├── RenderPipeline/  
|   |   ├── PrimitiveAssembler/
|   |   ├── Rasterizer/
|   |   |   ├── FrontEnd/
|   |   |   └── Backend/
|   |   ├── VertexShader/
|   |   ├── VertexPostProcessor/
│   │   └── TransformPipeline/
│   └── SPI/  
│       ├── src/
│       │   ├── spi_master.sv  
│       │   └── spi_slave.sv  
│       └── tb/
│           └── spi_master_tb.cpp
├── Documentation/  
│   ├── FPGA_spesification.pdf  
│   └── Module_documentation.md  
├── Constraints/  
│   ├── Arty-A7100t.xdc  
│   └── MH-System.xdc  
├── Data/  
├── Build/  
│   ├── build.tcl  
│   └── program.tcl  
├── README.md  
└── LICENSE  
</pre>
  
## Documentation
The spesification for the system can be found here:
[Project Specification](Documentation/Specification/FPGA-Specification.pdf)  
**THIS IS OUTDATED, A MORE UP TO DATE VERSION WILL COME (I SWEAR)**

## Testing
For each of the modules in the **lib/** directory, a __src__ and a __tb__ directories are provided.
The testbenches for the src files are provided in the tb directory. All testbenches are written in C++
and are utilizing [Verilator](https://github.com/verilator/verilator).

## Building the project
To build the project run the following inside the **Build/** directory

```
mkdir logs
vivado -mode batch -source build.tcl -log logs/build.log -journal logs/build.jou
```
