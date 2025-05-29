`timescale 1s / 1ps
`define PRECISION 32

// A B C

module ALU #(
    parameter reg [31:0] K = 32'h3eaaaaab  // 0.3333333432674407958984375
) (
    input wire ACLK,
    input wire ARESETN,

    input wire [`PRECISION-1:0] S_AXIS_A,
    input wire [`PRECISION-1:0] S_AXIS_B,
    input wire [`PRECISION-1:0] S_AXIS_C,
    input wire S_AXIS_TVALID,
    input wire S_AXIS_TLAST,
    output wire S_AXIS_TREADY,

    output wire [`PRECISION-1:0] M_AXIS_TDATA,
    output wire M_AXIS_TVALID,
    output wire M_AXIS_TLAST,
    input wire M_AXIS_TREADY
);

  // Level 0 - Sum A+B; Hold C
  wire LVL0_A_READY, LVL0_B_READY;
  wire LVL0_TVALID, LVL0_TLAST, LVL0_TREADY;
  wire [`PRECISION-1:0] LVL0_AB_TDATA, LVL0_C_TDATA;

  assign S_AXIS_TREADY = LVL0_A_READY & LVL0_B_READY;

  FPSum SumAB (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(S_AXIS_TVALID),
      .s_axis_a_tready(LVL0_A_READY),
      .s_axis_a_tdata (S_AXIS_A),
      .s_axis_a_tlast (S_AXIS_TLAST),

      .s_axis_b_tvalid(S_AXIS_TVALID),
      .s_axis_b_tready(LVL0_B_READY),
      .s_axis_b_tdata (S_AXIS_B),

      .m_axis_result_tvalid(LVL0_TVALID),
      .m_axis_result_tready(LVL0_TREADY),
      .m_axis_result_tdata (LVL0_AB_TDATA),
      .m_axis_result_tlast (LVL0_TLAST)
  );

  SR32Lat7 HoldC (
      .D  (S_AXIS_C),
      .CLK(ACLK),
      .CE (S_AXIS_TREADY),
      .Q  (LVL0_C_TDATA)
  );

  // Level 1 - Sum AB + C
  wire LVL1_AB_READY, LVL1_C_READY;
  wire LVL1_TVALID, LVL1_TLAST, LVL1_TREADY;
  wire [`PRECISION-1:0] LVL1_ABC_TDATA;

  assign LVL0_TREADY = LVL1_AB_READY & LVL1_C_READY;

  FPSum SumABC (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL0_TVALID),
      .s_axis_a_tready(LVL1_AB_READY),
      .s_axis_a_tdata (LVL0_AB_TDATA),
      .s_axis_a_tlast (LVL0_TLAST),

      .s_axis_b_tvalid(LVL0_TVALID),
      .s_axis_b_tready(LVL1_C_READY),
      .s_axis_b_tdata (LVL0_C_TDATA),

      .m_axis_result_tvalid(LVL1_TVALID),
      .m_axis_result_tready(LVL1_TREADY),
      .m_axis_result_tdata (LVL1_ABC_TDATA),
      .m_axis_result_tlast (LVL1_TLAST)
  );

  // Level 2 - Mul K * ABC
  wire LVL2_ABC_READY, LVL2_K_READY;

  assign LVL1_TREADY = LVL2_ABC_READY & LVL2_K_READY;

  FPMul MulKABC (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL1_TVALID),
      .s_axis_a_tready(LVL2_ABC_READY),
      .s_axis_a_tdata (LVL1_ABC_TDATA),
      .s_axis_a_tlast (LVL1_TLAST),

      .s_axis_b_tvalid(LVL1_TVALID),
      .s_axis_b_tready(LVL2_K_READY),
      .s_axis_b_tdata (K),

      .m_axis_result_tvalid(M_AXIS_TVALID),
      .m_axis_result_tready(M_AXIS_TREADY),
      .m_axis_result_tdata (M_AXIS_TDATA),
      .m_axis_result_tlast (M_AXIS_TLAST)
  );


endmodule
