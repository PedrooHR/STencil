`timescale 1s / 1ps
`define PRECISION 32
`define STATEWIDTH 2

module Queue #(
    parameter reg [15:0] SHIFTWIDTH = 16,
    parameter reg [15:0] COLUMNS = 3, // actually 4, but 0 counts
    parameter reg [15:0] ROWS = 127, 
    parameter reg [15:0] SQUARE = 511
) (
    input wire ACLK,
    input wire ARESETN,
    input wire SOFT_RESET,

    // Input Data
    input wire [2*SHIFTWIDTH*`PRECISION-1:0] S_TDATA,
    output reg S_TREADY,
    input wire S_TLAST,
    input wire S_TVALID,

    output wire [2*SHIFTWIDTH*`PRECISION-1:0] M_UPPER_TDATA,
    output wire [2*SHIFTWIDTH*`PRECISION-1:0] M_BACK_TDATA,
    output wire [(2*SHIFTWIDTH+2)*`PRECISION-1:0] M_CENTER_TDATA,
    output wire [2*SHIFTWIDTH*`PRECISION-1:0] M_FRONT_TDATA,
    output wire [2*SHIFTWIDTH*`PRECISION-1:0] M_BOTTOM_TDATA,
    input wire M_TREADY,
    output reg M_TLAST,
    output reg M_TVALID
);
  // FIFOs Control and Wiring
  wire [1023:0] CENTER_Q_DOUT;    // Also 2*SHIFTWIDTH*`PRECISION-1
  reg CENTER_Q_WRITE_EN = 1'b0, CENTER_Q_READ_EN = 1'b0;
  wire [1023:0] MIDBACK_Q_DOUT;      // Also 2*SHIFTWIDTH*`PRECISION-1
  reg MIDBACK_Q_WRITE_EN = 1'b0, MIDBACK_Q_READ_EN = 1'b0;
  wire [1023:0] MIDFRONT_Q_DOUT;     // Also 2*SHIFTWIDTH*`PRECISION-1
  reg MIDFRONT_Q_WRITE_EN = 1'b0, MIDFRONT_Q_READ_EN = 1'b0;
  wire [1023:0] BOTTOM_Q_DOUT;    // Also 2*SHIFTWIDTH*`PRECISION-1
  reg BOTTOM_Q_WRITE_EN = 1'b0, BOTTOM_Q_READ_EN = 1'b0;

  // State Machine Controls and Wiring
  localparam reg [2:0] StateIdle = 3'b000;
  localparam reg [2:0] StateReset = 3'b001;
  localparam reg [2:0] StateComputeInput = 3'b010;
  localparam reg [2:0] StateShift = 3'b100;
  reg [2:0] State = StateReset;

  // Generic Logic Control
  reg Computed = 1'b0;
  reg ReadInput = 1'b0;

  // Counters
  reg [15:0] ColumnCounter = 16'd0;
  reg [15:0] RowCounter = 16'd0;
  reg [15:0] CenterQCount = 16'd0;
  reg [15:0] MidBackQCount = 16'd0;
  reg [15:0] MidFrontQCount = 16'd0;
  reg [15:0] BottomQCount = 16'd0;

  // Pad Wiring
  wire [`PRECISION-1:0] LeftPad;
  reg [31:0] LeftPadInReg = 32'd0;
  reg LeftPadEnable = 1'b0;
  reg [`PRECISION-1:0] RightPad;
 
  // Input/Output Wiring
  reg [2*SHIFTWIDTH*`PRECISION-1:0] InputData = {2*SHIFTWIDTH * `PRECISION{1'b0}};
  reg [2*SHIFTWIDTH*`PRECISION-1:0] UpperData = {2*SHIFTWIDTH * `PRECISION{1'b0}};

  // First and Last Data Control
  reg LastData = 1'b0;
  reg FirstData = 1'b0;
  reg Finished = 1'b0;
  reg IgnoreLast = 1'b1;

  // FIFOs Empty/Full Control 
  reg CenterQEmpty = 1'b1;
  reg MidBackQEmpty = 1'b1;
  reg MidBackQPreEmpty = 1'b1;
  reg MidFrontQEmpty = 1'b1;
  reg BottomQEmpty = 1'b1;
  reg CenterQFull = 1'b0;
  reg MidBackQFull = 1'b0;
  reg MidFrontQFull = 1'b0;
  reg BottomQFull = 1'b0;

  // Queue Instances
  BR1024FIFO512 CenterQueue (
    .clk(ACLK),                         // input wire clk
    .srst(!ARESETN | SOFT_RESET),       // input wire srst
    .din(UpperData),                    // input wire [1023 : 0] din
    .wr_en(CENTER_Q_WRITE_EN),          // input wire wr_en
    .dout(CENTER_Q_DOUT),               // output wire [1023 : 0] dout
    .rd_en(CENTER_Q_READ_EN)            // input wire rd_en
  );

  BR1024FIFO512 MidBackQueue(
    .clk(ACLK),                         // input wire clk
    .srst(!ARESETN | SOFT_RESET),       // input wire srst
    .din(CENTER_Q_DOUT),                // input wire [1023 : 0] din
    .wr_en(MIDBACK_Q_WRITE_EN),         // input wire wr_en
    .dout(MIDBACK_Q_DOUT),              // output wire [1023 : 0] dout
    .rd_en(MIDBACK_Q_READ_EN)           // input wire rd_en
  );

  BR1024FIFO512B MidFrontQueue (
    .clk(ACLK),                         // input wire clk
    .srst(!ARESETN | SOFT_RESET),       // input wire srst
    .din(MIDBACK_Q_DOUT),               // input wire [1023 : 0] din
    .wr_en(MIDFRONT_Q_WRITE_EN),        // input wire wr_en
    .dout(MIDFRONT_Q_DOUT),             // output wire [1023 : 0] dout
    .rd_en(MIDFRONT_Q_READ_EN)          // input wire rd_en
  );

  BR1024FIFO512B BottomQueue (
    .clk(ACLK),                         // input wire clk
    .srst(!ARESETN | SOFT_RESET),       // input wire srst
    .din(MIDFRONT_Q_DOUT),              // input wire [1023 : 0] din
    .wr_en(BOTTOM_Q_WRITE_EN),          // input wire wr_en
    .dout(BOTTOM_Q_DOUT),               // output wire [1023 : 0] dout
    .rd_en(BOTTOM_Q_READ_EN)            // input wire rd_en
  );

  SR32Lat3 PadLeft (
    .CLK(ACLK),                         // input wire CLK
    .SCLR(!ARESETN | SOFT_RESET),       // input wire SCLR
    .CE(LeftPadEnable),                 // input wire CE
    .D(LeftPadInReg),  // input wire [31 : 0] D
    .Q(LeftPad)                     // output wire [31 : 0] Q
  );

  // Queue Empty/Full Logic
  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      CenterQEmpty <= 1'b1;
      MidBackQEmpty <= 1'b1;
      MidBackQPreEmpty <= 1'b1;
      MidFrontQEmpty <= 1'b1;
      BottomQEmpty <= 1'b1;
      CenterQFull <= 1'b0;
      MidBackQFull <= 1'b0;
      MidFrontQFull <= 1'b0;
      BottomQFull <= 1'b0;
    end else begin
      CenterQEmpty <= CenterQCount == 16'd0 ? 1'b1 : 1'b0;
      MidBackQEmpty <= MidBackQCount == 16'd0 ? 1'b1 : 1'b0;
      MidBackQPreEmpty <= MidBackQCount <= 16'd1 ? 1'b1 : 1'b0;
      MidFrontQEmpty <= MidFrontQCount == 16'd0 ? 1'b1 : 1'b0;
      BottomQEmpty <= BottomQCount == 16'd0 ? 1'b1 : 1'b0;
      CenterQFull <= CenterQCount >= (SQUARE - COLUMNS - 1) ? 1'b1 : 1'b0;
      MidBackQFull <= MidBackQCount >= (COLUMNS) ? 1'b1 : 1'b0;
      MidFrontQFull <= MidFrontQCount >= (COLUMNS - 1) ? 1'b1 : 1'b0;
      BottomQFull <= BottomQCount >= (SQUARE - COLUMNS - 2) ? 1'b1 : 1'b0;
    end
  end

  // First Data Logic
  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      FirstData <= 1'b0;
    end else begin
      if (!FirstData & S_TREADY & S_TVALID) begin
        FirstData <= 1'b1;
      end
    end
  end

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

  // State Machine Logic
  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      State <= StateReset;
    end else begin
      case (State)
        StateIdle: begin
        end
        StateReset: begin
          S_TREADY <= 1'b1;
          M_TVALID <= 1'b0;

          CENTER_Q_WRITE_EN <= 1'b0;
          CENTER_Q_READ_EN <= 1'b0;
          MIDBACK_Q_WRITE_EN <= 1'b0;
          MIDBACK_Q_READ_EN <= 1'b0;
          MIDFRONT_Q_WRITE_EN <= 1'b0;
          MIDFRONT_Q_READ_EN <= 1'b0;
          BOTTOM_Q_WRITE_EN <= 1'b0;
          BOTTOM_Q_READ_EN <= 1'b0;
          CenterQCount <= 16'd0;
          MidBackQCount <= 16'd0;
          MidFrontQCount <= 16'd0;
          BottomQCount <= 16'd0;

          Computed <= 1'b1;
          ReadInput <= 1'b0;
          IgnoreLast <= 1'b1;
          Finished <= 1'b0;
          InputData  <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
          UpperData  <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
          LeftPadInReg <= 32'd0;
          ColumnCounter <= 16'd0;
          RowCounter <= 16'd0;

          LeftPadEnable <= 1'b0;

          State <= StateComputeInput;
        end
        StateComputeInput: begin

          if (CENTER_Q_WRITE_EN) begin
            CenterQCount <= CenterQCount + 16'd1;
          end
          if (MIDBACK_Q_WRITE_EN) begin
            MidBackQCount <= MidBackQCount + 16'd1;
          end
          if (MIDFRONT_Q_WRITE_EN) begin
            MidFrontQCount <= MidFrontQCount + 16'd1;
          end
          if (BOTTOM_Q_WRITE_EN) begin
            BottomQCount <= BottomQCount + 16'd1;
          end

          CENTER_Q_WRITE_EN <= 1'b0;
          MIDBACK_Q_WRITE_EN <= 1'b0;
          MIDFRONT_Q_WRITE_EN <= 1'b0;
          BOTTOM_Q_WRITE_EN <= 1'b0;

          CENTER_Q_READ_EN <= 1'b0;
          MIDBACK_Q_READ_EN <= 1'b0;
          MIDFRONT_Q_READ_EN <= 1'b0;
          BOTTOM_Q_READ_EN <= 1'b0;

          // There are a few cases in here
          if (!ReadInput & S_TREADY & S_TVALID) begin
            InputData <= S_TDATA;
            S_TREADY <= 1'b0;
            ReadInput <= 1'b1;
          end

          // should verify queue's valid, but always 1
          if (!Computed & M_TVALID & M_TREADY) begin
            M_TVALID <= 1'b0;
            M_TLAST <= 1'b0;
            Computed <= 1'b1;
          end

          if (((M_TVALID & M_TREADY) | Computed) & ((S_TREADY & S_TVALID) | ReadInput)) begin
            if (!IgnoreLast) begin
              InputData <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
            end

            // RIGHT PADDING
            if (ColumnCounter == 16'd0 | MidBackQEmpty) begin
              RightPad <= 32'd0;
            end else begin
              RightPad <= MIDBACK_Q_DOUT[2*SHIFTWIDTH*`PRECISION-1-:`PRECISION];
            end
            
            // LEFT PADDING
            if (ColumnCounter == 16'd1) begin
              LeftPadInReg <= 32'd0;
            end else begin
              LeftPadInReg <= CENTER_Q_DOUT[`PRECISION-1:0];
            end          
            LeftPadEnable <= CenterQFull | !MidBackQEmpty;

            if (Finished) begin
              State <= StateIdle;
            end else begin
              State <= StateShift;
            end
          end
        end
        StateShift: begin
          LeftPadEnable <= 1'b0;

          if (LastData & IgnoreLast) begin
            IgnoreLast <= 1'b0;
          end

          if (LastData & MidBackQPreEmpty) begin
            Finished <= 1'b1;
          end

          // FIFO CONTROLLING
          if (CenterQFull | (LastData & !CenterQEmpty)) begin
            CENTER_Q_READ_EN <= 1'b1;
            CenterQCount <= CenterQCount - 16'd1;
          end

          if (MidBackQFull | (CenterQEmpty & !MidBackQEmpty)) begin
            MIDBACK_Q_READ_EN <= 1'b1;
            MidBackQCount <= MidBackQCount - 16'd1;
          end

          if (MidFrontQFull | (MidBackQEmpty & !MidFrontQEmpty)) begin
            MIDFRONT_Q_READ_EN <= 1'b1;
            MidFrontQCount <= MidFrontQCount - 16'd1;
          end
          
          if (BottomQFull | (MidFrontQEmpty & !BottomQEmpty)) begin
            BOTTOM_Q_READ_EN <= 1'b1;
            BottomQCount <= BottomQCount - 16'd1;
          end

          CENTER_Q_WRITE_EN <= FirstData & (!LastData | IgnoreLast);
          MIDBACK_Q_WRITE_EN <= CenterQFull | (LastData & !CenterQEmpty);
          MIDFRONT_Q_WRITE_EN <= MidBackQFull | (CenterQEmpty & !MidBackQEmpty);
          BOTTOM_Q_WRITE_EN <= MidFrontQFull | (MidBackQEmpty & !MidFrontQEmpty);

          // Input registering
          UpperData <= InputData;

          // OTHER LOGIC
          S_TREADY <= !LastData;
          ReadInput <= LastData;
          
          M_TLAST <= LastData & MidBackQPreEmpty;
          M_TVALID <= MidBackQFull | (LastData & !MidBackQEmpty);
          Computed <= !(MidBackQFull | (LastData & !MidBackQEmpty));  

          if (FirstData) begin
            if (ColumnCounter >= COLUMNS) begin
              ColumnCounter <= 16'd0;
              RowCounter <= RowCounter >= ROWS ? 16'd0 : RowCounter + 16'd1;
            end else begin
              ColumnCounter <= ColumnCounter + 16'd1;
            end
          end

          State <= StateComputeInput;
        end
        default: begin
          State <= StateReset;
        end
      endcase
    end
  end

  assign M_UPPER_TDATA = {UpperData};
  assign M_BACK_TDATA = {CENTER_Q_DOUT};
  assign M_CENTER_TDATA = {LeftPad, MIDBACK_Q_DOUT, RightPad}; 
  assign M_FRONT_TDATA = {MIDFRONT_Q_DOUT};
  assign M_BOTTOM_TDATA = {BOTTOM_Q_DOUT};

endmodule
