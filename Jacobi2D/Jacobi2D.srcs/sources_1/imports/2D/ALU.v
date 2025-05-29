`timescale 1s / 1ps
`define PRECISION 32

//   D
// A B C
//   E

module ALU #(
    parameter reg [31:0] K = 32'h3e4ccccd  // 0.20000000298023223876953125
) (
    input wire ACLK,
    input wire ARESETN,

    input wire [`PRECISION-1:0] S_AXIS_A,
    input wire [`PRECISION-1:0] S_AXIS_B,
    input wire [`PRECISION-1:0] S_AXIS_C,
    input wire [`PRECISION-1:0] S_AXIS_D,
    input wire [`PRECISION-1:0] S_AXIS_E,
    input wire S_AXIS_TVALID,
    input wire S_AXIS_TLAST,
    output wire S_AXIS_TREADY,

    output wire [`PRECISION-1:0] M_AXIS_TDATA,
    output wire M_AXIS_TVALID,
    output wire M_AXIS_TLAST,
    input wire M_AXIS_TREADY
);
  // LEVEL 0 - SIGNALS
  wire LVL0_A_TREADY, LVL0_C_TREADY, LVL0_D_TREADY, LVL0_E_TREADY;
  wire LVL0_AD_TVALID, LVL0_AD_TLAST, LVL0_AD_TREADY;
  wire LVL0_CE_TVALID, LVL0_CE_TLAST, LVL0_CE_TREADY;
  wire [`PRECISION-1:0] LVL0_AD_TDATA, LVL0_CE_TDATA, LVL0_B_TDATA;

  assign S_AXIS_TREADY = LVL0_A_TREADY & LVL0_C_TREADY & LVL0_D_TREADY & LVL0_E_TREADY;

  // LEVEL 1 - SIGNALS
  wire LVL1_AD_TREADY, LVL1_CE_TREADY;
  wire LVL1_ADCE_TVALID, LVL1_ADCE_TLAST, LVL1_ADCE_TREADY;
  wire [`PRECISION-1:0] LVL1_ADCE_TDATA, LVL1_B_TDATA;

  assign LVL1_TREADY = LVL1_AD_TREADY & LVL1_CE_TREADY;

  // LEVEL 2 - SIGNALS
  wire LVL2_ADCE_TREADY, LVL2_B_TREADY;
  wire LVL2_ADCEB_TVALID, LVL2_ADCEB_TLAST, LVL2_ADCEB_TREADY;
  wire [`PRECISION-1:0] LVL2_ADCEB_TDATA, LVL_2_B;

  assign LVL2_TREADY = LVL2_ADCE_TREADY & LVL2_B_TREADY;

  // LEVEL 3 - SIGNALS
  wire LVL3_ADCEB_TREADY, LVL3_K_TREADY;

  assign LVL3_TREADY = LVL3_ADCEB_TREADY & LVL3_K_TREADY;

  // Level 0 - Sum A+D; Sum C+E; Hold B
  FPSum SumAD (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(S_AXIS_TVALID),
      .s_axis_a_tready(LVL0_A_TREADY),
      .s_axis_a_tdata (S_AXIS_A),
      .s_axis_a_tlast (S_AXIS_TLAST),

      .s_axis_b_tvalid(S_AXIS_TVALID),
      .s_axis_b_tready(LVL0_D_TREADY),
      .s_axis_b_tdata (S_AXIS_D),

      .m_axis_result_tvalid(LVL0_AD_TVALID),
      .m_axis_result_tready(LVL1_TREADY),
      .m_axis_result_tdata (LVL0_AD_TDATA),
      .m_axis_result_tlast (LVL0_AD_TLAST)
  );

  FPSum SumCE (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(S_AXIS_TVALID),
      .s_axis_a_tready(LVL0_C_TREADY),
      .s_axis_a_tdata (S_AXIS_C),
      .s_axis_a_tlast (S_AXIS_TLAST),

      .s_axis_b_tvalid(S_AXIS_TVALID),
      .s_axis_b_tready(LVL0_E_TREADY),
      .s_axis_b_tdata (S_AXIS_E),

      .m_axis_result_tvalid(LVL0_CE_TVALID),
      .m_axis_result_tready(LVL1_TREADY),
      .m_axis_result_tdata (LVL0_CE_TDATA),
      .m_axis_result_tlast (LVL0_CE_TLAST)
  );

  SR32Lat7 HoldB_0 (
      .D  (S_AXIS_B),
      .CLK(ACLK),
      .CE (S_AXIS_TREADY),
      .Q  (LVL0_B_TDATA)
  );

  // Level 1 - Sum AD + CE, Hold B
  FPSum SumADCE (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL0_AD_TVALID),
      .s_axis_a_tready(LVL1_AD_TREADY),
      .s_axis_a_tdata (LVL0_AD_TDATA),
      .s_axis_a_tlast (LVL0_AD_TLAST),

      .s_axis_b_tvalid(LVL0_CE_TVALID),
      .s_axis_b_tready(LVL1_CE_TREADY),
      .s_axis_b_tdata (LVL0_CE_TDATA),

      .m_axis_result_tvalid(LVL1_ADCE_TVALID),
      .m_axis_result_tready(LVL2_TREADY),
      .m_axis_result_tdata (LVL1_ADCE_TDATA),
      .m_axis_result_tlast (LVL1_ADCE_TLAST)
  );

  SR32Lat7 HoldB_1 (
      .D  (LVL0_B_TDATA),
      .CLK(ACLK),
      .CE (LVL1_TREADY),
      .Q  (LVL1_B_TDATA)
  );

  // Level 2 - Sum ADCE + B
  FPSum SumADCEB (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL1_ADCE_TVALID),
      .s_axis_a_tready(LVL2_ADCE_TREADY),
      .s_axis_a_tdata (LVL1_ADCE_TDATA),
      .s_axis_a_tlast (LVL1_ADCE_TLAST),

      .s_axis_b_tvalid(LVL1_ADCE_TVALID),
      .s_axis_b_tready(LVL2_B_TREADY),
      .s_axis_b_tdata (LVL1_B_TDATA),

      .m_axis_result_tvalid(LVL2_ADCEB_TVALID),
      .m_axis_result_tready(LVL3_TREADY),
      .m_axis_result_tdata (LVL2_ADCEB_TDATA),
      .m_axis_result_tlast (LVL2_ADCEB_TLAST)
  );

  // Level 3 - Mul K * ADCEB
  FPMul MulKADCEB (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL2_ADCEB_TVALID),
      .s_axis_a_tready(LVL3_ADCEB_TREADY),
      .s_axis_a_tdata (LVL2_ADCEB_TDATA),
      .s_axis_a_tlast (LVL2_ADCEB_TLAST),

      .s_axis_b_tvalid(LVL2_ADCEB_TVALID),
      .s_axis_b_tready(LVL3_K_TREADY),
      .s_axis_b_tdata (K),

      .m_axis_result_tvalid(M_AXIS_TVALID),
      .m_axis_result_tready(M_AXIS_TREADY),
      .m_axis_result_tdata (M_AXIS_TDATA),
      .m_axis_result_tlast (M_AXIS_TLAST)
  );


endmodule
