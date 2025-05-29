`timescale 1s / 1ps
`define PRECISION 32
`define STATEWIDTH 2

module Sink #(
    parameter reg [15:0] SHIFTWIDTH = 16
) (
    input wire ACLK,
    input wire ARESETN,
    input wire SOFT_RESET,

    // Input Data
    input wire [(2*SHIFTWIDTH)*`PRECISION-1:0] S_UPPER_TDATA,
    input wire [(2*SHIFTWIDTH)*`PRECISION-1:0] S_BACK_TDATA,
    input wire [(2*SHIFTWIDTH+2)*`PRECISION-1:0] S_CENTER_TDATA,
    input wire [(2*SHIFTWIDTH)*`PRECISION-1:0] S_FRONT_TDATA,
    input wire [(2*SHIFTWIDTH)*`PRECISION-1:0] S_BOTTOM_TDATA,
    output reg S_TREADY,
    input wire S_TLAST,
    input wire S_TVALID,

    // Output Data
    output wire [SHIFTWIDTH*`PRECISION-1:0] M_UPPER_TDATA,
    output wire [SHIFTWIDTH*`PRECISION-1:0] M_BACK_TDATA,
    output wire [(SHIFTWIDTH+2)*`PRECISION-1:0] M_CENTER_TDATA,
    output wire [SHIFTWIDTH*`PRECISION-1:0] M_FRONT_TDATA,
    output wire [SHIFTWIDTH*`PRECISION-1:0] M_BOTTOM_TDATA,
    input wire M_TREADY,
    output reg M_TLAST,
    output reg M_TVALID
);

  reg [(2*SHIFTWIDTH)*`PRECISION-1:0] UpperReg = {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};
  reg [(2*SHIFTWIDTH)*`PRECISION-1:0] BackReg = {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};
  reg [(2*SHIFTWIDTH+2)*`PRECISION-1:0] CenterReg = {(2 * SHIFTWIDTH + 2) * `PRECISION{1'b0}};
  reg [(2*SHIFTWIDTH)*`PRECISION-1:0] FrontReg = {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};
  reg [(2*SHIFTWIDTH)*`PRECISION-1:0] BottomReg = {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};

  localparam reg [2:0] StateIdle = 3'b000;
  localparam reg [2:0] StateReset = 3'b001;
  localparam reg [2:0] StateSinkRight = 3'b010;
  localparam reg [2:0] StateSinkLeft = 3'b100;
  reg [2:0] State = StateReset;

  reg IgnoreLast = 1'b1;
  reg IgnoreFirst = 1'b1;
  reg PassLast = 1'b0;

  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      State <= StateReset;
    end else begin
      case (State)
        StateIdle: begin
        end
        StateReset: begin
          UpperReg <= {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};
          BackReg <= {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};
          CenterReg <= {(2 * SHIFTWIDTH + 2) * `PRECISION{1'b0}};
          FrontReg <= {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};
          BottomReg <= {(2 * SHIFTWIDTH) * `PRECISION{1'b0}};

          IgnoreLast <= 1'b1;
          IgnoreFirst <= 1'b1;
          PassLast <= 1'b0;
          M_TLAST <= 1'b0;

          State   <= StateSinkRight;
        end
        StateSinkRight: begin
          if (S_TVALID & S_TREADY) begin
            UpperReg <= S_UPPER_TDATA;
            BackReg <= S_BACK_TDATA;
            CenterReg <= S_CENTER_TDATA;
            FrontReg <= S_FRONT_TDATA;
            BottomReg <= S_BOTTOM_TDATA;
            IgnoreFirst <= 1'b0;
            if (S_TLAST) begin
              PassLast <= 1'b1;
            end
            State   <= StateSinkLeft;
          end else if (PassLast & M_TREADY) begin
            PassLast <= 1'b0;
            IgnoreLast <= 1'b0;
            M_TLAST <= 1'b0;
            State  <= StateIdle;
          end
        end
        StateSinkLeft: begin
          if (M_TVALID & M_TREADY) begin
            if (PassLast) begin
              M_TLAST <= 1'b1;
            end
            State <= StateSinkRight;
          end
        end
        default: begin
          State <= StateReset;
        end
      endcase
    end
  end

  always @(*) begin 
    case (State) 
      StateIdle: begin
        M_TVALID <= 1'b0;
        S_TREADY <= 1'b0;
      end
      StateReset: begin 
        M_TVALID <= 1'b0;
        S_TREADY <= 1'b0;
      end
      StateSinkRight: begin 
        M_TVALID <= (!IgnoreFirst & S_TVALID) | (PassLast & IgnoreLast);
        S_TREADY <= M_TREADY;
      end
      StateSinkLeft: begin 
        M_TVALID <= 1'b1;
        S_TREADY <= 1'b0;
      end
      default: begin
        M_TVALID <= 1'b0;
        S_TREADY <= 1'b0;
      end
    endcase
  end

  assign M_UPPER_TDATA = ((State == StateSinkRight) | (State == StateIdle)) ?  UpperReg[(2*SHIFTWIDTH)*`PRECISION-1-:SHIFTWIDTH*`PRECISION] : UpperReg[SHIFTWIDTH*`PRECISION-1:0];
  assign M_BACK_TDATA = ((State == StateSinkRight) | (State == StateIdle)) ? BackReg[(2*SHIFTWIDTH)*`PRECISION-1-:SHIFTWIDTH*`PRECISION] : BackReg[SHIFTWIDTH*`PRECISION-1:0];
  assign M_CENTER_TDATA = ((State == StateSinkRight) | (State == StateIdle)) ? CenterReg[(2*SHIFTWIDTH+2)*`PRECISION-1-:(SHIFTWIDTH+2)*`PRECISION] : CenterReg[(SHIFTWIDTH+2)*`PRECISION-1:0];
  assign M_FRONT_TDATA = ((State == StateSinkRight) | (State == StateIdle)) ? FrontReg[(2*SHIFTWIDTH)*`PRECISION-1-:SHIFTWIDTH*`PRECISION] : FrontReg[SHIFTWIDTH*`PRECISION-1:0];
  assign M_BOTTOM_TDATA = ((State == StateSinkRight) | (State == StateIdle)) ? BottomReg[(2*SHIFTWIDTH)*`PRECISION-1-:SHIFTWIDTH*`PRECISION] : BottomReg[SHIFTWIDTH*`PRECISION-1:0];

endmodule
