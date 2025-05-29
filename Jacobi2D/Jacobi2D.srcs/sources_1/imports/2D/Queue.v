`timescale 1s / 1ps
`define PRECISION 32
`define STATEWIDTH 2

module Queue #(
    parameter reg [15:0] SHIFTWIDTH = 16,
    parameter reg [8:0] COLUMNS = 255
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
    output wire [(2*SHIFTWIDTH+2)*`PRECISION-1:0] M_CENTER_TDATA,
    output wire [2*SHIFTWIDTH*`PRECISION-1:0] M_BOTTOM_TDATA,
    input wire M_TREADY,
    output reg M_TLAST,
    output reg M_TVALID
);
  // FIFOs Control and Wiring
  wire [1023:0] CENTER_Q_DOUT;
  reg CENTER_Q_WRITE_EN = 1'b0, CENTER_Q_READ_EN = 1'b0;
  wire [1023:0] BOTTOM_Q_DOUT;
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
  reg [8:0] ColumnCounter = 9'd0;
  reg [8:0] CenterQCount = 9'd0;
  reg [8:0] BottomQCount = 9'd0;

  // Pad Wiring
  wire [`PRECISION-1:0] LeftPadWire;
  reg LeftPadEnable = 1'b0;
 
  // Input/Output Wiring
  reg [2*SHIFTWIDTH*`PRECISION-1:0] InputData = {2*SHIFTWIDTH * `PRECISION{1'b0}};
  reg [2*SHIFTWIDTH*`PRECISION-1:0] UpperData = {2*SHIFTWIDTH * `PRECISION{1'b0}};
  reg [2*SHIFTWIDTH*`PRECISION-1:0] CenterData = {2*SHIFTWIDTH * `PRECISION{1'b0}};
  reg [2*SHIFTWIDTH*`PRECISION-1:0] BottomData = {2*SHIFTWIDTH * `PRECISION{1'b0}};
  reg [`PRECISION-1:0] LeftPad;
  reg [`PRECISION-1:0] RightPad;

  // First and Last Data Control
  reg LastData = 1'b0;
  reg FirstData = 1'b0;
  reg IgnoreLast = 1'b1;
  reg Finished = 1'b0;

  // FIFOs Empty/Full Control 
  reg CenterQEmpty = 1'b1;
  reg BottomQEmpty = 1'b1;
  reg CenterQFull = 1'b0;
  reg BottomQFull = 1'b0;

  // Queue Instances
  BR1024FIFO16 CenterQueue (
    .clk(ACLK),                     // input wire clk
    .srst(!ARESETN | SOFT_RESET),   // input wire srst
    .din(UpperData),                // input wire [1023 : 0] din
    .wr_en(CENTER_Q_WRITE_EN),      // input wire wr_en
    .dout(CENTER_Q_DOUT),           // output wire [1023 : 0] dout
    .rd_en(CENTER_Q_READ_EN)        // input wire rd_en
  );

  BR1024FIFO16 BottomQueue (
    .clk(ACLK),                     // input wire clk
    .srst(!ARESETN | SOFT_RESET),   // input wire srst
    .din(CENTER_Q_DOUT),            // input wire [1023 : 0] din
    .wr_en(BOTTOM_Q_WRITE_EN),      // input wire wr_en
    .dout(BOTTOM_Q_DOUT),           // output wire [1023 : 0] dout
    .rd_en(BOTTOM_Q_READ_EN)        // input wire rd_en
  );

  SR32Lat15 PadLeft (
    .CLK(ACLK),                     // input wire CLK
    .SCLR(!ARESETN | SOFT_RESET),   // input wire SCLR
    .CE(LeftPadEnable),             // input wire CE
    .D(UpperData[`PRECISION-1:0]),  // input wire [31 : 0] D
    .Q(LeftPadWire)                 // output wire [31 : 0] Q
  );

  // Queue Empty/Full Logic
  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      CenterQEmpty <= 1'b1;
      BottomQEmpty <= 1'b1;
      CenterQFull <= 1'b0;
      BottomQFull <= 1'b0;
    end else begin
      CenterQEmpty <= CenterQCount == 9'd0 ? 1'b1 : 1'b0;
      BottomQEmpty <= BottomQCount <= 9'd1 ? 1'b1 : 1'b0;
      CenterQFull <= CenterQCount >= COLUMNS ? 1'b1 : 1'b0;
      BottomQFull <= BottomQCount >= COLUMNS ? 1'b1 : 1'b0;
    end
  end

  // First Data Logic
  always @(posedge ACLK) begin
    if (!ARESETN | SOFT_RESET) begin
      FirstData <= 1'b0;
    end else begin
      if (!FirstData & S_TREADY & S_TVALID) begin
        // The very first data we read. We read this cycle and becomes true next
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
          M_TLAST  <= 1'b0;

          CENTER_Q_WRITE_EN <= 1'b0;
          CENTER_Q_READ_EN <= 1'b0;
          BOTTOM_Q_WRITE_EN <= 1'b0;
          BOTTOM_Q_READ_EN <= 1'b0;
          CenterQCount <= 9'd0;
          BottomQCount <= 9'd0;

          Finished <= 1'b0;
          Computed <= 1'b1;
          ReadInput <= 1'b0;
          UpperData  <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
          CenterData <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
          BottomData <= {2 * SHIFTWIDTH * `PRECISION{1'b0}};
          ColumnCounter <= 9'd0;
          IgnoreLast <= 1'b1;

          LeftPadEnable <= 1'b0;

          State <= StateComputeInput;
        end
        StateComputeInput: begin
          LeftPadEnable <= 1'b0;

          if (CENTER_Q_WRITE_EN) begin
            CenterQCount <= CenterQCount + 9'd1;
          end
          if (BOTTOM_Q_WRITE_EN) begin
            BottomQCount <= BottomQCount + 9'd1;
          end

          CENTER_Q_WRITE_EN <= 1'b0;
          BOTTOM_Q_WRITE_EN <= 1'b0;
          CENTER_Q_READ_EN <= 1'b0;
          BOTTOM_Q_READ_EN <= 1'b0;

          // There are a few cases in here
          if (!ReadInput & S_TREADY & S_TVALID) begin
            InputData <= S_TDATA;
            S_TREADY <= 1'd0;
            ReadInput <= 1'd1;
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

            if (FirstData) begin
              ColumnCounter <= ColumnCounter >= COLUMNS ? 9'd0 : ColumnCounter + 9'd1;
            end

            if (Finished) begin
              State <= StateIdle;
            end else begin
              State <= StateShift;
            end
          end
        end
        StateShift: begin
          if (LastData & IgnoreLast) begin
            IgnoreLast <= 1'b0;
          end

          if (LastData & BottomQEmpty) begin
            Finished <= 1'b1;
          end

          // RIGHT PADDING
          if (ColumnCounter == 9'd0 | CenterQEmpty) begin
            RightPad <= 32'd0;
          end else begin
            RightPad <= CenterData[2*SHIFTWIDTH*`PRECISION-1-:`PRECISION];
          end

          // LEFT PADDING
          if (ColumnCounter >= COLUMNS) begin
            LeftPad <= 32'd0;
          end else begin
            LeftPad <= LeftPadWire;
          end          
          LeftPadEnable <= FirstData; // As soon as we have the first data, start shifting

          // FIFO CONTROLLING
          if (CenterQFull | (LastData & !CenterQEmpty)) begin
            CENTER_Q_READ_EN <= 1'b1;
            CenterData <= CENTER_Q_DOUT;
            CenterQCount <= CenterQCount - 9'd1;
          end

          if (BottomQFull | LastData) begin
            BOTTOM_Q_READ_EN <= 1'b1;
            BottomData <= BOTTOM_Q_DOUT;
            BottomQCount <= BottomQCount - 9'd1;
          end

          CENTER_Q_WRITE_EN <= FirstData & (!LastData | IgnoreLast);
          BOTTOM_Q_WRITE_EN <= CenterQFull & (!LastData | IgnoreLast);

          // Input registering
          UpperData <= InputData;

          // OTHER LOGIC
          S_TREADY <= !LastData;
          ReadInput <= LastData;

          M_TLAST <= LastData & BottomQEmpty;
          M_TVALID <= CenterQFull | (LastData & !CenterQEmpty);
          Computed <= !(CenterQFull | (LastData & !CenterQEmpty));  

          State <= StateComputeInput;
        end
        default: begin
          State <= StateReset;
        end
      endcase
    end
  end

  // Assignments Logic
  assign M_UPPER_TDATA = {UpperData};
  assign M_CENTER_TDATA = {LeftPad, CenterData, RightPad};
  assign M_BOTTOM_TDATA = {BottomData};

endmodule
