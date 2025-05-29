`timescale 1s / 1ps
`define PRECISION 32

module BlockALU #(
    parameter reg [15:0] SHIFTWIDTH = 16,
    parameter reg [31:0] K = 32'h3e000000,  // 0.125
    parameter reg [31:0] Z = 32'h3f000000   // 0.5 (-> 1/8 * -2 * 2)
) (
    input wire ACLK,
    input wire ARESETN,

    input wire [SHIFTWIDTH*`PRECISION-1:0] S_UPPER_TDATA,
    input wire [(SHIFTWIDTH+2)*`PRECISION-1:0] S_CENTER_TDATA,
    input wire [SHIFTWIDTH*`PRECISION-1:0] S_BOTTOM_TDATA,
    input wire S_TVALID,
    input wire S_TLAST,
    output wire S_TREADY,

    output wire [SHIFTWIDTH*`PRECISION-1:0] M_TDATA,
    output wire M_TVALID,
    output wire M_TLAST,
    input wire M_TREADY
);

  wire [SHIFTWIDTH - 1:0] M_ALU_Valid;
  wire [SHIFTWIDTH - 1:0] M_ALU_Last;
  wire [SHIFTWIDTH - 1:0] S_ALU_Ready;

  assign M_TVALID = M_ALU_Valid[0];
  assign M_TLAST  = M_ALU_Last[0];
  assign S_TREADY = S_ALU_Ready[0];

  generate
    for (genvar I = 0; I < SHIFTWIDTH; I = I + 1) begin : gen_ALU_I
      ALU #(
          .K(K),
          .Z(Z)
      ) I_ALU (
          .ACLK (ACLK),
          .ARESETN(ARESETN),

          .S_AXIS_A(S_CENTER_TDATA[(I+0)*`PRECISION+:`PRECISION]),
          .S_AXIS_B(S_CENTER_TDATA[(I+1)*`PRECISION+:`PRECISION]),
          .S_AXIS_C(S_CENTER_TDATA[(I+2)*`PRECISION+:`PRECISION]),
          .S_AXIS_D(S_UPPER_TDATA[I*`PRECISION+:`PRECISION]),
          .S_AXIS_E(S_BOTTOM_TDATA[I*`PRECISION+:`PRECISION]),

          .S_AXIS_TVALID(S_TVALID),
          .S_AXIS_TLAST (S_TLAST),
          .S_AXIS_TREADY(S_ALU_Ready[I]),

          .M_AXIS_TDATA (M_TDATA[I*`PRECISION+:`PRECISION]),
          .M_AXIS_TVALID(M_ALU_Valid[I]),
          .M_AXIS_TLAST (M_ALU_Last[I]),
          .M_AXIS_TREADY(M_TREADY)
      );
    end
  endgenerate

endmodule

