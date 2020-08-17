module lifo #(
  parameter int DWIDTH = 8,
  parameter int AWIDTH = 4
)(
  input                         clk_i,
  input                         srst_i,

  input                         wrreq_i,
  input        [DWIDTH - 1 : 0] data_i,

  input                         rdreq_i,
  output logic [DWIDTH - 1 : 0] q_o,

  output logic                  empty_o,
  output logic                  full_o,
  output logic [AWIDTH : 0]     usedw_o
);

localparam LIFO_DEPTH = 2**AWIDTH;

logic [DWIDTH - 1 : 0] mem [LIFO_DEPTH - 1 : 0];

logic [AWIDTH - 1 : 0] wr_ptr;
logic [AWIDTH - 1 : 0] rd_ptr;

always_ff @( posedge clk_i )
  if( srst_i )
    usedw_o <= '0;
  else if( wrreq_i )
    usedw_o <= usedw_o + 1'b1;
  else if( rdreq_i )
    usedw_o <= usedw_o - 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    full_o <= 1'b0;
  else if( rdreq_i )
    full_o <= 1'b0;
  else if( wrreq_i && ( usedw_o == ( LIFO_DEPTH - 1 ) ) )
    full_o <= 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    empty_o <= 1'b1;
  else if( wrreq_i )
    empty_o <= 1'b0;
  else if( rdreq_i && ( usedw_o == 1 ) )
    empty_o <= 1'b1;

// Sync RAM inferring
always_ff @( posedge clk_i )
  begin
    if( wrreq_i )
      mem[wr_ptr] <= data_i;
    if( rdreq_i )
      q_o <= mem[rd_ptr];
  end

always_ff @( posedge clk_i )
  if( srst_i )
    wr_ptr <= '0;
  else if( wrreq_i )
    wr_ptr <= wr_ptr + 1'b1;
  else if( rdreq_i )
    wr_ptr <= wr_ptr - 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    rd_ptr <= '0;
  else if( wrreq_i )
    rd_ptr <= wr_ptr;
  else if( rdreq_i )
    rd_ptr <= rd_ptr - 1'b1;

endmodule : lifo