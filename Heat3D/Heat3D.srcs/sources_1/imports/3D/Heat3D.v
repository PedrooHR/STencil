`timescale 1s / 1ps
`define PRECISION 32

module Heat3D #(
    parameter reg [15:0] SHIFTWIDTH = 16,
    parameter reg [15:0] WIDTH = 128,
    parameter reg [15:0] HEIGHT = 128,
    parameter reg [31:0] K = 32'h3e000000,  // 0.125
    parameter reg [31:0] Z = 32'h3e800000   // 0.25 (1/8*-2*B + 1/8*-2*B + 1/8*-2*B + B) 
) (
    //General signals:
    input wire ACLK,
    input wire ARESETN,

    //Slave AXIS interface:
    input wire [SHIFTWIDTH*`PRECISION-1:0] S_AXIS_TDATA,
    input wire S_AXIS_TVALID,
    input wire S_AXIS_TLAST,
    //TKEEP is ignored.Always considers a block a unit and valid as a whole.
    input wire [SHIFTWIDTH*`PRECISION/8-1:0] S_AXIS_TKEEP,
    output wire S_AXIS_TREADY,

    //Master AXIS interface:
    output wire [SHIFTWIDTH*`PRECISION-1:0] M_AXIS_TDATA,
    output wire M_AXIS_TVALID,
    output wire M_AXIS_TLAST,
    //TKEEP is set to high. Always considers a block valid as a whole.
    output wire [SHIFTWIDTH*`PRECISION/8-1:0] M_AXIS_TKEEP,
    input wire M_AXIS_TREADY
);
  // Signals
  wire [2*SHIFTWIDTH*`PRECISION-1:0] QUEUE_S_TDATA;
  wire QUEUE_S_TLAST;
  wire QUEUE_S_TREADY;
  wire QUEUE_S_TVALID;

  wire [2*SHIFTWIDTH*`PRECISION-1:0] SINK_UPPER_TDATA;
  wire [2*SHIFTWIDTH*`PRECISION-1:0] SINK_BACK_TDATA;
  wire [(2*SHIFTWIDTH+2)*`PRECISION-1:0] SINK_CENTER_TDATA;
  wire [2*SHIFTWIDTH*`PRECISION-1:0] SINK_FRONT_TDATA;
  wire [2*SHIFTWIDTH*`PRECISION-1:0] SINK_BOTTOM_TDATA;
  wire SINK_S_TLAST;
  wire SINK_S_TREADY;
  wire SINK_S_TVALID;

  wire [SHIFTWIDTH*`PRECISION-1:0] ALU_UPPER_TDATA;
  wire [SHIFTWIDTH*`PRECISION-1:0] ALU_BACK_TDATA;
  wire [(SHIFTWIDTH+2)*`PRECISION-1:0] ALU_CENTER_TDATA;
  wire [SHIFTWIDTH*`PRECISION-1:0] ALU_FRONT_TDATA;
  wire [SHIFTWIDTH*`PRECISION-1:0] ALU_BOTTOM_TDATA;
  wire ALU_S_TLAST;
  wire ALU_S_TREADY;
  wire ALU_S_TVALID;

  // Last Data Logic
  reg SOFT_RESET = 1'b0;
  
  always @(posedge ACLK) begin
    if (!ARESETN) begin
      SOFT_RESET <= 1'b0;
    end else begin
      if (M_AXIS_TLAST & M_AXIS_TVALID & M_AXIS_TREADY) begin
        SOFT_RESET <= 1'b1;
      end else begin
        SOFT_RESET <= 1'b0;
      end
    end
  end
  
  // Keep Logic
  reg [SHIFTWIDTH*`PRECISION/8-1:0] RegKeep = {SHIFTWIDTH * `PRECISION / 8{1'h1}};
  assign M_AXIS_TKEEP = RegKeep; 

  Collector #(
      .SHIFTWIDTH(SHIFTWIDTH)
  ) I_Collector (
      .ACLK(ACLK),
      .ARESETN(ARESETN),
      .SOFT_RESET(SOFT_RESET),

      .S_TDATA (S_AXIS_TDATA),
      .S_TLAST (S_AXIS_TLAST),
      .S_TREADY(S_AXIS_TREADY),
      .S_TVALID(S_AXIS_TVALID),

      .M_TDATA (QUEUE_S_TDATA),
      .M_TLAST (QUEUE_S_TLAST),
      .M_TREADY(QUEUE_S_TREADY),
      .M_TVALID(QUEUE_S_TVALID)
  );


  Queue #(
      .SHIFTWIDTH(SHIFTWIDTH),
      .COLUMNS((WIDTH / (SHIFTWIDTH * 2)) - 1),
      .ROWS(HEIGHT - 1), // Row-wise, we only read 1 row per time
      .SQUARE(((WIDTH * HEIGHT) / (SHIFTWIDTH * 2)) - 1)
  ) I_Queue (
      .ACLK(ACLK),
      .ARESETN(ARESETN),
      .SOFT_RESET(SOFT_RESET),

      .S_TDATA (QUEUE_S_TDATA),
      .S_TLAST (QUEUE_S_TLAST),
      .S_TREADY(QUEUE_S_TREADY),
      .S_TVALID(QUEUE_S_TVALID),

      .M_UPPER_TDATA(SINK_UPPER_TDATA),
      .M_BACK_TDATA(SINK_BACK_TDATA),
      .M_CENTER_TDATA(SINK_CENTER_TDATA),
      .M_FRONT_TDATA(SINK_FRONT_TDATA),
      .M_BOTTOM_TDATA(SINK_BOTTOM_TDATA),
      .M_TLAST (SINK_S_TLAST),
      .M_TREADY(SINK_S_TREADY),
      .M_TVALID(SINK_S_TVALID)
  );

  Sink #(
      .SHIFTWIDTH(SHIFTWIDTH)
  ) I_Sink (
      .ACLK(ACLK),
      .ARESETN(ARESETN),
      .SOFT_RESET(SOFT_RESET),

      .S_UPPER_TDATA(SINK_UPPER_TDATA),
      .S_BACK_TDATA(SINK_BACK_TDATA),
      .S_CENTER_TDATA(SINK_CENTER_TDATA),
      .S_FRONT_TDATA(SINK_FRONT_TDATA),
      .S_BOTTOM_TDATA(SINK_BOTTOM_TDATA),
      .S_TLAST (SINK_S_TLAST),
      .S_TREADY(SINK_S_TREADY),
      .S_TVALID(SINK_S_TVALID),

      .M_UPPER_TDATA(ALU_UPPER_TDATA),
      .M_BACK_TDATA(ALU_BACK_TDATA),
      .M_CENTER_TDATA(ALU_CENTER_TDATA),
      .M_FRONT_TDATA(ALU_FRONT_TDATA),
      .M_BOTTOM_TDATA(ALU_BOTTOM_TDATA),
      .M_TLAST (ALU_S_TLAST),
      .M_TREADY(ALU_S_TREADY),
      .M_TVALID(ALU_S_TVALID)
  );

  BlockALU #(
      .SHIFTWIDTH(SHIFTWIDTH),
      .K(K),
      .Z(K)
  ) I_BlockALU (
      .ACLK(ACLK),
      .ARESETN(ARESETN),

      .S_UPPER_TDATA(ALU_UPPER_TDATA),
      .S_BACK_TDATA(ALU_BACK_TDATA),
      .S_CENTER_TDATA(ALU_CENTER_TDATA),
      .S_FRONT_TDATA(ALU_FRONT_TDATA),
      .S_BOTTOM_TDATA(ALU_BOTTOM_TDATA),
      .S_TLAST (ALU_S_TLAST),
      .S_TREADY(ALU_S_TREADY),
      .S_TVALID(ALU_S_TVALID),

      .M_TDATA (M_AXIS_TDATA),
      .M_TLAST (M_AXIS_TLAST),
      .M_TREADY(M_AXIS_TREADY),
      .M_TVALID(M_AXIS_TVALID)
  );

endmodule
