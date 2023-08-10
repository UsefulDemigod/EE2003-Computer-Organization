# Single Cycle CPU Synthesis with yosys

This repo contains additional scripts for synthesis using yosys and post synth simulations.

## Goals

- To be able to produce a synthesizable design of your single cycle CPU.

## Details on the assignment

Most of the things are the same as the original single cycle CPU assignment. You will notice that in the file "program_file_synth.txt", the last file that is included is a file present in the yosys installation location. In particular, it comes under the xilinx folder. This is because the synth.ys (a script for yosys) generates a verilog output after synthesis and this will require additional modules/primitives, which define the actual hardware on the board. Here we use the xilinx primitives, and hence we need to specify the appropriate location of the file that includes the definition of these primitives.

**IMPORTANT**: Add all your verilog module file names in synth.ys in the line read verilog. For help, already regfile.v and and alu.v have been added. If you do not have these files delete them from synth.ys and add your files.

Once you make these changes, execute the run.sh file to synthesise the design using yosys, and perform post synth simulations with the same test cases.

Before you try out bitstream generation using vivado on the ee2003 server, you are strongly advised to try out this post synth simulation. This makes it easy to resolve issues, and prevents multiple running vivado instances from slowing down the system. Once you have confirmed that your code passes all the tests, follow the steps in the cpu_fpga repository to generate the final bitstream to run it with the Pynq interface.


