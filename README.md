# FPGA-src
The source files for the FPGA system, written in SystemVerilog.

## Overview 
The project is splitt into multiple modules and accompanying documentation in **Documentation/**.
The following is an overview of the project structure

<pre>
<strong>FPGA-src</strong>
├── src/  
│   └── top_mh_flight_sim_fpga.sv  
├── lib/  
│   ├── Framebuffer/  
│   │   └── framebuffer.sv  
│   ├── Display/  
│   │   └── display_480p.sv  
│   ├── RenderPipeline/  
│   │   └── Math/  
│   │       ├── mat_mat_mul_dim_4.sv  
│   │       └── mat_vec_mul_dim_4.sv  
│   └── SPI/  
│       ├── spi_master.sv  
│       └── spi_slave.sv  
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
[Project Specification](Documentation/FPGA-Specification.pdf) (Note: the spesification is written 
in norwegian)

## Testing
For each of the modules in the **lib/** directory, a __src__ and a __tb__ directories are provided.
The testbenches for the src files are provided in the tb directory. All testbenches are written in C++
and are utilizing [Verilator](https://github.com/verilator/verilator).

## Building the project
To build the project run the following inside the **Build/** directory

```
mkdir logs
viado -mode batch -source build.tcl -log logs/build.log -journal logs/build.jou
```
