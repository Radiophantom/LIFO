module lifo #(
  parameter int DWIDTH        = 8,
  parameter int AWIDTH        = 4,
  parameter int ALMOST_FULL   = 15,
  parameter int ALMOST_EMPTY  = 1
)(
  input               clk_i,
  input               srst_i,

  input               wrreq_i,
  input  [DWIDTH-1:0] data_i,

  input               rdreq_i,
  output [DWIDTH-1:0] q_o,

  output              almost_empty_o,
  output              empty_o,
  output              almost_full_o,
  output              full_o,
  output [AWIDTH:0]   usedw_o
);

//******************************************************************************
// Parameters and Variables declaration
//******************************************************************************

localparam LIFO_DEPTH = 2**AWIDTH;

logic [DWIDTH-1:0]   mem [0:LIFO_DEPTH-1];

logic [AWIDTH-1:0]   wr_ptr;
logic [AWIDTH-1:0]   rd_ptr;

logic [DWIDTH-1:0]   q;
logic                empty;
logic                almost_empty;
logic                full;
logic                almost_full;
logic [AWIDTH:0]     usedw;

logic                wrreq_d;
logic                rdreq_d;

logic                wrreq;
logic                rdreq;

logic                insert_rd_ptr_error;
logic                insert_wr_ptr_error;

//******************************************************************************
// Error injection logic
//******************************************************************************

always_ff @( posedge clk_i )
  begin
    wrreq_d <= wrreq_i;
    rdreq_d <= rdreq_i;
  end

//******************************************************************************
// LIFO logic
//******************************************************************************

assign wrreq = wrreq_i && !full_o;
assign rdreq = rdreq_i && !empty_o;

always_ff @( posedge clk_i )
  if( srst_i )
    usedw <= '0;
  else
    // Bug injection !!!
    // No 'overflow'/'underrun' protection
    case( {wrreq_i,rdreq_i} )
      2'b10:
        begin
          usedw <= usedw + 1'b1;
        end

      2'b01:
        begin
          usedw <= usedw - 1'b1;
        end
      default: usedw <= usedw;
    endcase

always_ff @( posedge clk_i )
  if( srst_i )
    full <= 1'b0;
  else
    if( rdreq_i )
      full <= 1'b0;
    else
      if( wrreq_i && ( usedw == ( LIFO_DEPTH - 1 ) ) )
        full <= 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    // Bug injection !!!
    // Must be 1'b1 after reset!
    empty <= 1'b0;
  else
    if( wrreq_i )
      empty <= 1'b0;
    else
      if( rdreq_i && ( usedw == 1 ) )
        empty <= 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    almost_full <= 1'b0;
  else
    case( {wrreq_i,rdreq_i} )
      2'b10:
        begin
          almost_full <= ( usedw >= ALMOST_FULL - 1 );
        end

      2'b01:
        begin
          almost_full <= ( usedw > ALMOST_FULL );
        end

      default: almost_full <= almost_full;
    endcase

always_ff @( posedge clk_i )
  if( srst_i )
    almost_empty <= 1'b1;
  else
    case( {wrreq_i,rdreq_i} )
      2'b10:
        begin
          almost_empty <= ( usedw < ALMOST_EMPTY );
        end

      2'b01:
        begin
          // Bug injection !!!
          // Must be:
          // almost_empty <= ( usedw <= ALMOST_EMPTY + 1 );
          almost_empty <= ( usedw < ALMOST_EMPTY + 1 );
        end

      default: almost_empty <= almost_empty;
    endcase

// Sync RAM inferring
always_ff @( posedge clk_i )
  begin
    if( wrreq && rdreq )
      begin
        // Bug injection !!!
        // Simultaneous 'write' and 'read' request, when
        // only 1 word left in LIFO, mask new input data.
        if( usedw == 1 )
          mem[wr_ptr-1] <= mem[wr_ptr-1];
        else
          mem[wr_ptr-1] <= data_i;
      end
    else
      if( wrreq )
        mem[wr_ptr] <= data_i;
    if( rdreq )
      // Bug injection !!!
      // Simultaneous 'read' and 'write' request, when
      // LIFO is almost-full (only 1 word left),
      // returns old data.
      if( wrreq && usedw == ( LIFO_DEPTH - 1 ) )
        q <= mem[rd_ptr-1];
      else
        q <= mem[rd_ptr];
  end

always_ff @( posedge clk_i )
  if( srst_i )
    wr_ptr <= '0;
  else
    case( {wrreq,rdreq} )
      2'b10:
        begin
          // Bug injection !!!
          // If no 'idle' ticks passed after
          // LIFO has begun empty, then immediate writing
          // cause pointer reference error.
          if( !(rdreq_d == 1'b1 && empty_o) )
            wr_ptr <= wr_ptr + 1'b1;
        end

      2'b01:
        begin
          wr_ptr <= wr_ptr - 1'b1;
        end

      default: wr_ptr <= wr_ptr;
    endcase

always_ff @( posedge clk_i )
  if( srst_i )
    rd_ptr <= '0;
  else
    case( {wrreq,rdreq} )
      2'b10:
        begin
          rd_ptr <= wr_ptr;
        end

      2'b01:
        begin
          // Bug injection !!!
          // If no 'idle' ticks passed after
          // LIFO has begun full, then immediate writing
          // cause pointer reference error.
          if( !(wrreq_d == 1'b1 && full_o) )
            rd_ptr <= rd_ptr - 1'b1;
        end

      default: rd_ptr <= rd_ptr;
    endcase

assign q_o            = q;
assign almost_empty_o = almost_empty;
assign empty_o        = empty;
assign almost_full_o  = almost_full;
assign full_o         = full;
assign usedw_o        = usedw;

endmodule : lifo
