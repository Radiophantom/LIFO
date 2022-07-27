`timescale 1ns / 1ps

`include "./random_scenario.sv"

module lifo_tb #(
  parameter int DWIDTH = 8,
  parameter int AWIDTH = 4
);

localparam int LIFO_DEPTH = 2**AWIDTH;

bit clk_i  = 0;
bit srst_i = 0;

logic                  wrreq_i;
logic [DWIDTH - 1 : 0] data_i;

logic                  rdreq_i;
logic [DWIDTH - 1 : 0] q_o;

logic                  empty_o;
logic                  full_o;
logic [AWIDTH : 0]     usedw_o;

logic [AWIDTH : 0]     ref_usedw;
logic [DWIDTH - 1 : 0] ref_data;

logic                  wrreq_allowed;
logic                  rdreq_allowed;

always #5 clk_i = !clk_i;

random_scenario rnd_scenario;

lifo #(
  .DWIDTH  ( DWIDTH  ),
  .AWIDTH  ( AWIDTH  )
) lifo (
  .clk_i   ( clk_i   ),
  .srst_i  ( srst_i  ),

  .wrreq_i ( wrreq_i ),
  .data_i  ( data_i  ),

  .rdreq_i ( rdreq_i ),
  .q_o     ( q_o     ),

  .empty_o ( empty_o ),
  .full_o  ( full_o  ),
  .usedw_o ( usedw_o )
);

logic [DWIDTH - 1 : 0] lifo_data [$];

task automatic model();
  ref_usedw = 0;
  forever
    begin
      @( posedge clk_i );
      ref_usedw <= ref_usedw + ( wrreq_i && lifo_data.size() < LIFO_DEPTH) - ( rdreq_i && lifo_data.size() > 0 );
      if( rdreq_i && lifo_data.size() > 0)
        ref_data <= lifo_data.pop_back();
      if( wrreq_i && lifo_data.size() < LIFO_DEPTH)
        lifo_data.push_back( data_i );
    end
endtask

assign wrreq_allowed = ( ref_usedw < ( LIFO_DEPTH - 1 ) ) || ( ( ref_usedw == ( LIFO_DEPTH - 1 ) ));
assign rdreq_allowed = ( ref_usedw > 1 ) || ( ( ref_usedw == 1 ));

task automatic write_only();
  @( posedge clk_i );
  wrreq_i <= wrreq_allowed;
  rdreq_i <= 1'b0;
  data_i  <= $urandom();
endtask

task automatic read_only();
  @( posedge clk_i );
  rdreq_i <= rdreq_allowed;
  wrreq_i <= 1'b0;
endtask

task automatic read_write();
  @( posedge clk_i );
  wrreq_i <= wrreq_allowed;
  rdreq_i <= rdreq_allowed;
  data_i  <= $urandom();
endtask

task automatic idle();
  @( posedge clk_i );
  wrreq_i <= 1'b0;
  rdreq_i <= 1'b0;
endtask

task automatic run_tasks_scenario();
  bit [1:0] scenario [$];
  bit [1:0] current_task;
  rnd_scenario.get_scenario( scenario );
  while( scenario.size() != 0 )
    begin
      current_task = scenario.pop_front();
      case( current_task )
        2'd0 : idle();
        2'd1 : write_only();
        2'd2 : read_only();
        2'd3 : read_write();
      endcase
    end
  idle();
endtask


task automatic check ();
  forever
    begin
      @( posedge clk_i );
      if( ( !full_o && ( ref_usedw == LIFO_DEPTH ) ) || ( full_o && ( ref_usedw != LIFO_DEPTH ) ) )
        begin
          $display( "%0t : Unexpected full flag behavior", $time );
          $stop();
        end

      if( ( !empty_o && ( ref_usedw == 0 ) ) || ( empty_o && ( ref_usedw != 0 ) ) )
        begin
          $display( "%0t : Unexpected empty flag behavior", $time );
          $stop();
        end

      if( usedw_o != ref_usedw  )
        begin
          $display( "%0t : Unexpected usedw value", $time );
          $display( "Expected : %d", ref_usedw );
          $display( "Observed : %d", usedw_o   );
          $stop();
        end

      if( ref_data != q_o )
        begin
          $display( "%0t : Data word mismatch", $time );
          $display( "Expected : %h", ref_data );
          $display( "Observed : %h", q_o      );
          $stop();
        end
    end
endtask


initial
  begin
    $timeformat( -9, 0, " ns", 20 );
    wrreq_i = 1'b0;
    rdreq_i = 1'b0;
    rnd_scenario = new();

    @( posedge clk_i );
    srst_i = 1'b1;
    @( posedge clk_i );
    srst_i = 1'b0;

    repeat(5) @( posedge clk_i );

    fork
      model();
      check();
    join_none;

    rnd_scenario.set_probability(0, 100, 0, 0);
    rnd_scenario.create_scenario( 20 );
    rnd_scenario.set_probability(0, 0, 100, 0);
    rnd_scenario.create_scenario( 20 );
    run_tasks_scenario();

    rnd_scenario.set_probability(0, 70, 30, 0);
    rnd_scenario.create_scenario( 30 );
    run_tasks_scenario();

    rnd_scenario.set_probability( 0, 100, 0, 0 );
    rnd_scenario.create_scenario( 20 );
    run_tasks_scenario();

    rnd_scenario.set_probability( 0, 50, 50, 0 );
    rnd_scenario.create_scenario( 20 );
    run_tasks_scenario();

    repeat(5) @( posedge clk_i );

    $display( "Test successfully passed" );
    $stop();
  end

endmodule
