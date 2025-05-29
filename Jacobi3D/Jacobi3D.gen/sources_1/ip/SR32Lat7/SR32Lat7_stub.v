// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.1 (lin64) Build 3526262 Mon Apr 18 15:47:01 MDT 2022
// Date        : Tue Dec 31 23:20:37 2024
// Host        : fpga-a3 running 64-bit Ubuntu 18.04.6 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/pedro.rosso/stencil/stencil/Jacobi3D/Jacobi3D.runs/SR32Lat7_synth_1/SR32Lat7_stub.v
// Design      : SR32Lat7
// Purpose     : Stub declaration of top-level module interface
// Device      : xcu55c-fsvh2892-2L-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "c_shift_ram_v12_0_14,Vivado 2022.1" *)
module SR32Lat7(D, CLK, CE, Q)
/* synthesis syn_black_box black_box_pad_pin="D[31:0],CLK,CE,Q[31:0]" */;
  input [31:0]D;
  input CLK;
  input CE;
  output [31:0]Q;
endmodule
