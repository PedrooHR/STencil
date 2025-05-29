`timescale 1s / 1ps
`define PRECISION 32
`define STATEWIDTH 2

module Collector #(
    parameter reg [15:0] SHIFTWIDTH = 16
) (
    input wire ACLK,
    input wire ARESETN,
    input wire SOFT_RESET,

    // Input Data
    input wire [SHIFTWIDTH*`PRECISION-1:0] S_TDATA,
    output reg S_TREADY,
    input wire S_TLAST,
    input wire S_TVALID,

    // Output Data
    output wire [2*SHIFTWIDTH*`PRECISION-1:0] M_TDATA,
    input wire M_TREADY,
    output reg M_TLAST,
    output reg M_TVALID
);

  reg [2*SHIFTWIDTH*`PRECISION-1:0] DataReg = {2 * SHIFTWIDTH * `PRECISION{1'b0}};

  localparam reg [2:0] StateIdle = 3'b000;
  localparam reg [2:0] StateReset = 3'b001;
  localparam reg [2:0] StateCollectRight = 3'b010;
  localparam reg [2:0] StateCollectLeft = 3'b100;
  reg [2:0] State = StateReset;

  reg LastData = 1'b0;
  reg IgnoreFirst = 1'b1;
  reg IgnoreLast = 1'b1;

  assign M_TDATA = DataReg;

  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      State <= StateReset;
    end else begin
      case (State)
        StateIdle: begin
          if (M_TREADY & M_TVALID) begin
            IgnoreLast <= 1'b0;
            M_TLAST <= 1'b0;
          end
        end
        StateReset: begin
          DataReg <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
          IgnoreFirst <= 1'b1;
          IgnoreLast <= 1'b1;
          M_TLAST <= 1'b0;
          State <= StateCollectRight;
        end
        StateCollectRight: begin
          if (S_TVALID & S_TREADY) begin
            DataReg[SHIFTWIDTH*`PRECISION-1:0] <= S_TDATA;
            IgnoreFirst <= 1'b0;
            State <= StateCollectLeft;
          end
        end
        StateCollectLeft: begin // only place queue collects
          if (S_TVALID & S_TREADY) begin
            DataReg[2*SHIFTWIDTH*`PRECISION-1-:SHIFTWIDTH*`PRECISION] <= S_TDATA;

            if (S_TLAST) begin
              State <= StateIdle;
              M_TLAST <= 1'b1;
            end else begin
              State <= StateCollectRight;
            end
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
        M_TVALID <= IgnoreLast;
        S_TREADY <= 1'b0;
      end
      StateReset: begin 
        M_TVALID <= 1'b0;
        S_TREADY <= 1'b0;
      end
      StateCollectRight: begin 
        M_TVALID <= !IgnoreFirst & S_TVALID;
        S_TREADY <= M_TREADY;
      end
      StateCollectLeft: begin 
        M_TVALID <= 1'b0;
        S_TREADY <= 1'b1;
      end
      default: begin
        M_TVALID <= 1'b0;
        S_TREADY <= 1'b0;
      end
    endcase
  end

endmodule
