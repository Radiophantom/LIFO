module lifo #(
  parameter int DWIDTH = 8,
  parameter int AWIDTH = 4
)(
  input               clk_i,
  input               srst_i,

  input               wrreq_i,
  input  [DWIDTH-1:0] data_i,

  input               rdreq_i,
  output [DWIDTH-1:0] q_o,

  output              empty_o,
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
logic                full;
logic [AWIDTH:0]     usedw;

logic                wrreq_d;
logic                rdreq_d;

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

// Имитация "залипания" указателей при немедленной смене типа операции на
// граничных условиях.
assign insert_rd_ptr_error  = (wrreq_d == 1'b1 && full_o );
assign insert_wr_ptr_error  = (rdreq_d == 1'b1 && empty_o);

//******************************************************************************
// LIFO logic
//******************************************************************************

always_ff @( posedge clk_i )
  if( srst_i )
    usedw <= '0;
  else
    if( wrreq_i && !full )
      usedw <= usedw + 1'b1;
    else
      if( rdreq_i && !empty )
        usedw <= usedw - 1'b1;

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
    empty <= 1'b1;
  else
    if( wrreq_i )
      empty <= 1'b0;
    else
      if( rdreq_i && ( usedw == 1 ) )
        empty <= 1'b1;

// Sync RAM inferring
always_ff @( posedge clk_i )
  begin
    if( wrreq_i )
      mem[wr_ptr] <= data_i;
    if( rdreq_i )
      q <= mem[rd_ptr];
  end

always_ff @( posedge clk_i )
  if( srst_i )
    wr_ptr <= '0;
  else
    if( wrreq_i && !insert_wr_ptr_error)
      wr_ptr <= wr_ptr + 1'b1;
    else
      if( rdreq_i )
        wr_ptr <= wr_ptr - 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    rd_ptr <= '0;
  else
    if( wrreq_i )
      rd_ptr <= wr_ptr;
    else
      if( rdreq_i && !insert_rd_ptr_error )
        rd_ptr <= rd_ptr - 1'b1;

assign q_o      = q;
assign empty_o  = empty;
assign full_o   = full;
assign usedw_o  = usedw;

endmodule : lifo
