# FPGA-src
The source files for the FPGA system, written in SystemVerilog.

## Overview 
The project is splitt into multiple modules and accompanying documentation in **Documentation/**.
The following is an overview of the project structure

**FPGA-src**
├── src/
│   └── top\_mh\_flight\_sim\_fpga.sv
├── lib/
│   ├── Framebuffer/
│   │   └── framebuffer.sv
│   ├── Display/
│   │   └── display\_480p.sv
│   ├── RenderPipeline/
│   │   └── Math/
│   │       ├── mat\_mat\_mul\_dim\_4.sv
│   │       └── mat\_vec\_mul\_dim\_4.sv
│   └── SPI/
│       ├── spi\_master.sv
│       └── spi\_slave.sv
├── Documentation/
│   ├── FPGA\_spesification.pdf
│   └── Module\_documentation.md
├── Constraints/
│   ├── Arty-A7100t.xdc
│   └── MH-System.xdc
├── Data/
├── Build/
│   ├── build.tcl
│   └── program.tcl
├── README.md
└── LICENSE

## Documentation
The spesification for the system can be found in **Documentation/FPGA-Specification.pdf**.

## Testing
For each of the modules in the **lib/** directory, a __src__ and a __tb__ directories are provided.
The testbenches for the src files are provided in the tb directory. All testbenches are written in C++
and are utilizing *Verilator*.

## Building the project
To build the project run the following inside the **Build/** directory

```
mkdir logs
viado -mode batch -source build.tcl -log logs/build.log -journal logs/build.jou
```
