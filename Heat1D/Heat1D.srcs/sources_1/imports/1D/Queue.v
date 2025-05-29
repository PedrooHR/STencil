`timescale 1s / 1ps
`define PRECISION 32
`define STATEWIDTH 2

module Queue #(
    parameter reg [15:0] SHIFTWIDTH = 16
) (
    input wire ACLK,
    input wire ARESETN,
    input wire SOFT_RESET,

    // Input Data
    input wire [2*SHIFTWIDTH*`PRECISION-1:0] S_TDATA,
    output reg S_TREADY,
    input wire S_TLAST,
    input wire S_TVALID,

    output wire [(2*SHIFTWIDTH+2)*`PRECISION-1:0] M_TDATA,
    input wire M_TREADY,
    output reg M_TLAST,
    output reg M_TVALID
);

  // Shifting Queue Registers
  reg [6*SHIFTWIDTH*`PRECISION-1:0] DataReg = {6 * SHIFTWIDTH * `PRECISION{1'b0}};
  reg [`PRECISION-1:0] RightPad = {`PRECISION{1'b0}};

  localparam reg [2:0] StateIdle = 3'b000;
  localparam reg [2:0] StateReset = 3'b001;
  localparam reg [2:0] StateComputeInput = 3'b010;
  localparam reg [2:0] StateShift = 3'b100;
  reg [2:0] State = StateReset;

  reg Finished = 1'b0;
  reg Computed = 1'b0;
  reg ReadInput = 1'b0;

  // First and Last Data Control
  reg LastData = 1'b0;
  reg IgnoreFirst = 1'b1;
  reg IgnoreLast = 1'b1;

  // LastData Logic
  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      LastData <= 1'b0;
    end else begin
      if (S_TREADY & S_TVALID & S_TLAST) begin
        LastData <= 1'b1;
      end
    end
  end

  // State Machine Control
  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      State <= StateReset;
    end else begin
      case (State)
        StateIdle: begin
        end
        StateReset: begin
          S_TREADY <= 1'd1;
          M_TVALID <= 1'd0;
          M_TLAST <= 1'b0;

          Finished <= 1'b0;
          Computed <= 1'b1;
          ReadInput <= 1'b0;
          DataReg <= {6 * SHIFTWIDTH * `PRECISION{1'b0}};
          IgnoreLast <= 1'b1; 
          IgnoreFirst <= 1'b1;

          State <= StateComputeInput;
        end
        StateComputeInput: begin
          if (!ReadInput & S_TREADY & S_TVALID) begin
            DataReg[6*SHIFTWIDTH*`PRECISION-1-:2*SHIFTWIDTH*`PRECISION] <= S_TDATA;
            S_TREADY <= 1'b0;
            ReadInput <= 1'b1;
          end

          if (!Computed & M_TVALID & M_TREADY) begin
            M_TVALID <= 1'b0;
            M_TLAST <= 1'b0;
            Computed <= 1'b1;
          end

          if (((M_TVALID & M_TREADY) | Computed) & ((S_TREADY & S_TVALID) | ReadInput)) begin
            if (!IgnoreLast) begin
              DataReg[6*SHIFTWIDTH*`PRECISION-1-:2*SHIFTWIDTH*`PRECISION] <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
            end

            if (Finished) begin
              State <= StateIdle;
            end else begin
              State <= StateShift;
            end
          end
        end
        StateShift: begin
          // Have we finished inputs (This state after read the last input)
          if (LastData & IgnoreLast) begin
            IgnoreLast <= 1'b0;
          end

          if (!IgnoreLast) begin
            Finished <= 1'b1;
          end

          // Padding Right
          RightPad  <= DataReg[2*SHIFTWIDTH*`PRECISION-1-:`PRECISION];

          // Shifting
          DataReg   <= DataReg >> 2 * SHIFTWIDTH * `PRECISION;

          // Other Logic
          S_TREADY <= !LastData;
          ReadInput <= LastData;
          
          M_TLAST <= !IgnoreLast;

          M_TVALID <= !IgnoreFirst & !Finished;
          Computed <= IgnoreFirst;

          IgnoreFirst <= 1'b0;

          State <= StateComputeInput;
        end
        default: begin
          State <= StateReset;
        end
      endcase
    end
  end
 
  assign M_TDATA = {DataReg[(2*SHIFTWIDTH+1)*`PRECISION-1:0], RightPad};

endmodule
