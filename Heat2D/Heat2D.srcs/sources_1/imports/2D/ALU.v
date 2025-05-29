`timescale 1s / 1ps
`define PRECISION 32

//   D
// A B C
//   E

module ALU #(
    parameter reg [31:0] K = 32'h3e000000,  // 0.125 (1/8)
    parameter reg [31:0] Z = 32'h3f000000   // 0.5 (-> 1/8 * -2 * 2)
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
  wire LVL0_AC_TVALID, LVL0_AC_TLAST;
  wire LVL0_DE_TVALID, LVL0_DE_TLAST;
  wire [`PRECISION-1:0] LVL0_AC_TDATA, LVL0_DE_TDATA, LVL0_B_TDATA;

  assign S_AXIS_TREADY = LVL0_A_TREADY & LVL0_C_TREADY & LVL0_D_TREADY & LVL0_E_TREADY;

  // LEVEL 1 - SIGNALS
  wire LVL1_AC_TREADY, LVL1_DE_TREADY, LVL1_K1_TREADY, LVL1_K2_TREADY, LVL1_B_TREADY, LVL1_Z_TREADY;
  wire LVL1_KAC_TVALID, LVL1_KAC_TLAST;
  wire LVL1_KDE_TVALID, LVL1_KDE_TLAST;
  wire LVL1_ZB_TVALID, LVL1_ZB_TLAST;
  wire [`PRECISION-1:0] LVL1_KAC_TDATA, LVL1_KDE_TDATA, LVL1_ZB_TDATA;

  assign LVL1_TREADY = LVL1_AC_TREADY & LVL1_DE_TREADY & LVL1_K1_TREADY & LVL1_K2_TREADY & LVL1_B_TREADY & LVL1_Z_TREADY;

  // LEVEL 2 - SIGNALS
  wire LVL2_KAC_TREADY, LVL2_KDE_TREADY;
  wire LVL2_KACKDE_TVALID, LVL2_KACKDE_TLAST;
  wire [`PRECISION-1:0] LVL2_KACKDE_TDATA, LVL2_ZB_TDATA;

  assign LVL2_TREADY = LVL2_KAC_TREADY & LVL2_KDE_TREADY;

  // LEVEL 3 - SIGNALS
  wire LVL3_KACKDE_TREADY, LVL3_ZB_TREADY;

  assign LVL3_TREADY = LVL3_KACKDE_TREADY & LVL3_ZB_TREADY;

  // Level 0 - Sum A+C; Sum D+E; Hold B
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

      .m_axis_result_tvalid(LVL0_AC_TVALID),
      .m_axis_result_tready(LVL1_TREADY),
      .m_axis_result_tdata (LVL0_AC_TDATA),
      .m_axis_result_tlast (LVL0_AC_TLAST)
  );

  FPSum SumDE (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(S_AXIS_TVALID),
      .s_axis_a_tready(LVL0_D_TREADY),
      .s_axis_a_tdata (S_AXIS_D),
      .s_axis_a_tlast (S_AXIS_TLAST),

      .s_axis_b_tvalid(S_AXIS_TVALID),
      .s_axis_b_tready(LVL0_E_TREADY),
      .s_axis_b_tdata (S_AXIS_E),

      .m_axis_result_tvalid(LVL0_DE_TVALID),
      .m_axis_result_tready(LVL1_TREADY),
      .m_axis_result_tdata (LVL0_DE_TDATA),
      .m_axis_result_tlast (LVL0_DE_TLAST)
  );

  SR32Lat7 HoldB (
      .D  (S_AXIS_B),
      .CLK(ACLK),
      .CE (S_AXIS_TREADY),
      .Q  (LVL0_B_TDATA)
  );

  // Level 1 - Mul K*AC, Mul K*DE, Mul Z*B
  FPMul MulKAC (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL0_AC_TVALID),
      .s_axis_a_tready(LVL1_AC_TREADY),
      .s_axis_a_tdata (LVL0_AC_TDATA),
      .s_axis_a_tlast (LVL0_AC_TLAST),

      .s_axis_b_tvalid(LVL0_AC_TVALID),
      .s_axis_b_tready(LVL1_K1_TREADY),
      .s_axis_b_tdata (K),

      .m_axis_result_tvalid(LVL1_KAC_TVALID),
      .m_axis_result_tready(LVL2_TREADY),
      .m_axis_result_tdata (LVL1_KAC_TDATA),
      .m_axis_result_tlast (LVL1_KAC_TLAST)
  );

  FPMul MulKDE (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL0_DE_TVALID),
      .s_axis_a_tready(LVL1_DE_TREADY),
      .s_axis_a_tdata (LVL0_DE_TDATA),
      .s_axis_a_tlast (LVL0_DE_TLAST),

      .s_axis_b_tvalid(LVL0_DE_TVALID),
      .s_axis_b_tready(LVL1_K2_TREADY),
      .s_axis_b_tdata (K),

      .m_axis_result_tvalid(LVL1_KDE_TVALID),
      .m_axis_result_tready(LVL2_TREADY),
      .m_axis_result_tdata (LVL1_KDE_TDATA),
      .m_axis_result_tlast (LVL1_KDE_TLAST)
  );
  
  // B appears several times in the equation. MulZB condensates it in (0.5*B) -> (1/8*-2*B + 1/8*-2*B + B)  
  FPMul MulZB ( 
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL0_AC_TVALID), // Lets use one of LVL0 Tvalids here
      .s_axis_a_tready(LVL1_B_TREADY),
      .s_axis_a_tdata (LVL0_B_TDATA),
      .s_axis_a_tlast (LVL0_AC_TLAST),

      .s_axis_b_tvalid(LVL0_AC_TVALID), // Lets use one of LVL0 Tvalids here
      .s_axis_b_tready(LVL1_Z_TREADY),
      .s_axis_b_tdata (Z),

      .m_axis_result_tvalid(LVL1_ZB_TVALID),
      .m_axis_result_tready(LVL2_TREADY),
      .m_axis_result_tdata (LVL1_ZB_TDATA),
      .m_axis_result_tlast (LVL1_ZB_TLAST)
  );

  // Level 2 - Sum KAC + KDE
  FPSum SumKACKDE (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL1_KAC_TVALID),
      .s_axis_a_tready(LVL2_KAC_TREADY),
      .s_axis_a_tdata (LVL1_KAC_TDATA),
      .s_axis_a_tlast (LVL1_KAC_TLAST),

      .s_axis_b_tvalid(LVL1_KDE_TVALID),
      .s_axis_b_tready(LVL2_KDE_TREADY),
      .s_axis_b_tdata (LVL1_KDE_TDATA),

      .m_axis_result_tvalid(LVL2_KACKDE_TVALID),
      .m_axis_result_tready(LVL3_TREADY),
      .m_axis_result_tdata (LVL2_KACKDE_TDATA),
      .m_axis_result_tlast (LVL2_KACKDE_TLAST)
  );

  SR32Lat7 HoldZB (
      .D  (LVL1_ZB_TDATA),
      .CLK(ACLK),
      .CE (LVL2_TREADY),
      .Q  (LVL2_ZB_TDATA)
  );

  // Level 3 - Sum KACKDE + ZB
  FPSum SumKACKDEZB (
      .aclk(ACLK),
      .aresetn(ARESETN),

      .s_axis_a_tvalid(LVL2_KACKDE_TVALID),
      .s_axis_a_tready(LVL3_KACKDE_TREADY),
      .s_axis_a_tdata (LVL2_KACKDE_TDATA),
      .s_axis_a_tlast (LVL2_KACKDE_TLAST),

      .s_axis_b_tvalid(LVL2_KACKDE_TVALID),
      .s_axis_b_tready(LVL3_ZB_TREADY),
      .s_axis_b_tdata (LVL2_ZB_TDATA),

      .m_axis_result_tvalid(M_AXIS_TVALID),
      .m_axis_result_tready(M_AXIS_TREADY),
      .m_axis_result_tdata (M_AXIS_TDATA),
      .m_axis_result_tlast (M_AXIS_TLAST)
  );

endmodule
