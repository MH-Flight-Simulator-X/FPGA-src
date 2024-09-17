# FPGA-src
The source files for the FPGA system, written in SystemVerilog.

## Overview 
The project is splitt into multiple modules and accompanying documentation in **Documentation/**.
The following is an overview of the project structure

## Documentation
The spesification for the system can be found in **Documentation/FPGA-Specification.pdf**.

## Testing

## Building the project
To build the project run the following inside the **Build/** directory

```
mkdir logs
viado -mode batch -source build.tcl -log logs/build.log -journal logs/build.jou
```
