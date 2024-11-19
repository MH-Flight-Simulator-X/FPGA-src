```
    __  _____  __    _________       __    __     _____ _                 __      __                _  __
   /  |/  / / / /   / ____/ (_)___ _/ /_  / /_   / ___/(_)___ ___  __  __/ /___ _/ /_____  _____   | |/ /
  / /|_/ / /_/ /   / /_  / / / __ `/ __ \/ __/   \__ \/ / __ `__ \/ / / / / __ `/ __/ __ \/ ___/   |   /
 / /  / / __  /   / __/ / / / /_/ / / / / /_    ___/ / / / / / / / /_/ / / /_/ / /_/ /_/ / /      /   |
/_/  /_/_/ /_/   /_/   /_/_/\__, /_/ /_/\__/   /____/_/_/ /_/ /_/\__,_/_/\__,_/\__/\____/_/      /_/|_|
                           /____/
```
# FPGA-src
The source files for the FPGA system, written in SystemVerilog.

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
