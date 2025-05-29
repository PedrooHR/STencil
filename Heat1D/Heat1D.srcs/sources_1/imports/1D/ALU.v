`timescale 1s / 1ps
`define PRECISION 32

// C B A

module ALU #(
    parameter reg [31:0] K = 32'h3e000000,  // 0.125
    parameter reg [31:0] Z = 32'hbe800000   // -0.25 (-> 1/8 * -2)
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

  // Level 0 - Sum A+C; Hold B
  wire LVL0_A_TREADY, LVL0_C_TREADY;
  wire LVL0_TVALID, LVL0_TLAST, LVL0_TREADY;
  wire [`PRECISION-1:0] LVL0_AC_TDATA, LVL0_B_TDATA;

  assign S_AXIS_TREADY = LVL0_A_TREADY & LVL0_C_TREADY;

  FPSum SumAC (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(S_AXIS_TVALID),
      .s_axis_a_tready(LVL0_A_TREADY),
      .s_axis_a_tdata (S_AXIS_A),
      .s_axis_a_tlast (S_AXIS_TLAST),

      .s_axis_b_tvalid(S_AXIS_TVALID),
      .s_axis_b_tready(LVL0_C_TREADY),
      .s_axis_b_tdata (S_AXIS_C),

      .m_axis_result_tvalid(LVL0_TVALID),
      .m_axis_result_tready(LVL0_TREADY),
      .m_axis_result_tdata (LVL0_AC_TDATA),
      .m_axis_result_tlast (LVL0_TLAST)
  );

  SR32Lat7 HoldB (
      .D  (S_AXIS_B),
      .CLK(ACLK),
      .CE (S_AXIS_TREADY),
      .Q  (LVL0_B_TDATA)
  );

  // Level 1 - Mul K * AC; Mul Z * B
  wire LVL1_AC_TREADY, LVL1_B_TREADY, LVL1_K_TREADY, LVL1_Z_TREADY;
  wire LVL1_KAC_TVALID, LVL1_KAC_TLAST, LVL1_KAC_TREADY;
  wire [`PRECISION-1:0] LVL1_KAC_TDATA;
  wire LVL1_ZB_TVALID, LVL1_ZB_TLAST, LVL1_ZB_TREADY;
  wire [`PRECISION-1:0] LVL1_ZB_TDATA;

  assign LVL0_TREADY = LVL1_AC_TREADY & LVL1_B_TREADY & LVL1_K_TREADY & LVL1_Z_TREADY;

  FPMul MulKAC (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL0_TVALID),
      .s_axis_a_tready(LVL1_AC_TREADY),
      .s_axis_a_tdata (LVL0_AC_TDATA),
      .s_axis_a_tlast (LVL0_TLAST),

      .s_axis_b_tvalid(LVL0_TVALID),
      .s_axis_b_tready(LVL1_K_TREADY),
      .s_axis_b_tdata (K),

      .m_axis_result_tvalid(LVL1_KAC_TVALID),
      .m_axis_result_tready(LVL1_KAC_TREADY),
      .m_axis_result_tdata (LVL1_KAC_TDATA),
      .m_axis_result_tlast (LVL1_KAC_TLAST)
  );


  FPMul MulZB (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL0_TVALID),
      .s_axis_a_tready(LVL1_B_TREADY),
      .s_axis_a_tdata (LVL0_B_TDATA),
      .s_axis_a_tlast (LVL0_TLAST),

      .s_axis_b_tvalid(LVL0_TVALID),
      .s_axis_b_tready(LVL1_Z_TREADY),
      .s_axis_b_tdata (Z),

      .m_axis_result_tvalid(LVL1_ZB_TVALID),
      .m_axis_result_tready(LVL1_ZB_TREADY),
      .m_axis_result_tdata (LVL1_ZB_TDATA),
      .m_axis_result_tlast (LVL1_ZB_TLAST)
  );

  // Level 2 - Sum KAC + ZB
  FPSum SumABC (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL1_KAC_TVALID),
      .s_axis_a_tready(LVL1_KAC_TREADY),
      .s_axis_a_tdata (LVL1_KAC_TDATA),
      .s_axis_a_tlast (LVL1_KAC_TLAST),

      .s_axis_b_tvalid(LVL1_ZB_TVALID),
      .s_axis_b_tready(LVL1_ZB_TREADY),
      .s_axis_b_tdata (LVL1_ZB_TDATA),

      .m_axis_result_tvalid(M_AXIS_TVALID),
      .m_axis_result_tready(M_AXIS_TREADY),
      .m_axis_result_tdata (M_AXIS_TDATA),
      .m_axis_result_tlast (M_AXIS_TLAST)
  );

endmodule