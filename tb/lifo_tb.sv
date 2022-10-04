`timescale 1ns / 1ps

`include "./random_scenario.sv"

module lifo_tb #(
  parameter int DWIDTH       = 8,
  parameter int AWIDTH       = 4,
  parameter int ALMOST_FULL  = 15,
  parameter int ALMOST_EMPTY = 1
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
logic                  ref_full;
logic                  ref_empty;
logic                  ref_almost_full;
logic                  ref_almost_empty;

logic                  wrreq_allowed;
logic                  rdreq_allowed;

always #5 clk_i = !clk_i;

random_scenario rnd_scenario;

lifo #(
  .DWIDTH           ( DWIDTH            ),
  .AWIDTH           ( AWIDTH            ),
  .ALMOST_FULL      ( ALMOST_FULL       ),
  .ALMOST_EMPTY     ( ALMOST_EMPTY      )
) lifo (
  .clk_i            ( clk_i             ),
  .srst_i           ( srst_i            ),

  .wrreq_i          ( wrreq_i           ),
  .data_i           ( data_i            ),

  .rdreq_i          ( rdreq_i           ),
  .q_o              ( q_o               ),

  .almost_empty_o   ( almost_empty_o    ),
  .empty_o          ( empty_o           ),
  .almost_full_o    ( almost_full_o     ),
  .full_o           ( full_o            ),
  .usedw_o          ( usedw_o           )
);

logic [DWIDTH - 1 : 0] lifo_data [$];

task automatic model();
  ref_usedw         = 0;
  ref_full          = 1'b0;
  ref_almost_full   = 1'b0;
  ref_empty         = 1'b1;
  ref_almost_empty  = 1'b1;
  ref_data          = 'bX;
  lifo_data.delete();
  forever
    begin
      @( posedge clk_i );
        begin
          if( rdreq_i && !ref_empty )
            begin
              ref_data <= lifo_data.pop_back();
            end
          if( wrreq_i && !ref_full )
            begin
              lifo_data.push_back( data_i );
            end
          ref_usedw         <= lifo_data.size();
          ref_empty         <= ( lifo_data.size() == 0            );
          ref_full          <= ( lifo_data.size() == LIFO_DEPTH   );
          ref_almost_full   <= ( lifo_data.size() >= ALMOST_FULL  );
          ref_almost_empty  <= ( lifo_data.size() <= ALMOST_EMPTY );
        end
    end
endtask

task automatic write_only();
  @( posedge clk_i );
  wrreq_i <= 1'b1;
  rdreq_i <= 1'b0;
  data_i  <= $urandom();
endtask

task automatic read_only();
  @( posedge clk_i );
  rdreq_i <= 1'b1;
  wrreq_i <= 1'b0;
endtask

task automatic read_write();
  @( posedge clk_i );
  wrreq_i <= 1'b1;
  rdreq_i <= 1'b1;
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
  fork
    model();
    check();
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
  join_any
  idle();
  idle();
  disable fork;
endtask

task automatic check ();
  int error_occured = 0;
  forever
    begin
      @( posedge clk_i );
      if( full_o != ref_full )
        begin
          $display( "%0t : Unexpected full flag behavior", $time );
          $display( "Observed state : %b", full_o );
          error_occured = 1;
        end

      if( empty_o != ref_empty )
        begin
          $display( "%0t : Unexpected empty flag behavior", $time );
          $display( "Observed state : %b", empty_o );
        end

      if( almost_full_o != ref_almost_full )
        begin
          $display( "%0t : Unexpected almost-full flag behavior", $time );
          $display( "Observed state : %b", almost_full_o );
          error_occured = 1;
        end

      if( almost_empty_o != ref_almost_empty )
        begin
          $display( "%0t : Unexpected almost-empty flag behavior", $time );
          $display( "Observed state : %b", almost_empty_o );
        end

      if( usedw_o != ref_usedw  )
        begin
          $display( "%0t : Unexpected usedw value", $time );
          $display( "Expected : %d", ref_usedw );
          $display( "Observed : %d", usedw_o   );
          error_occured = 1;
        end

      if( q_o != ref_data )
        begin
          $display( "%0t : Data word mismatch", $time );
          $display( "Expected : %h", ref_data );
          $display( "Observed : %h", q_o      );
          error_occured = 1;
        end

      if( error_occured )
        return;
    end
endtask

task automatic reset_design();
  $display("%0t : Resetting design...", $time );
  @( posedge clk_i );
  srst_i = 1'b1;
  @( posedge clk_i );
  srst_i = 1'b0;
endtask

initial
  begin
    $timeformat( -9, 0, " ns", 20 );
    wrreq_i = 1'b0;
    rdreq_i = 1'b0;
    rnd_scenario = new();

    reset_design();

    // 'usedw' bug detection
    rnd_scenario.set_probability(0, 100, 0, 0);
    rnd_scenario.create_scenario( 20 );
    rnd_scenario.set_probability(100, 0, 0, 0);
    rnd_scenario.create_scenario( 1 );
    rnd_scenario.set_probability(0, 0, 100, 0);
    rnd_scenario.create_scenario( 20 );
    rnd_scenario.set_probability(100, 0, 0, 0);
    rnd_scenario.create_scenario( 1 );

    run_tasks_scenario();
    reset_design();

    // 'write pointer' bug detection
    rnd_scenario.set_probability( 0, 100, 0, 0 );
    rnd_scenario.create_scenario( 16 );
    rnd_scenario.set_probability( 0, 0, 100, 0);
    rnd_scenario.create_scenario( 16 );

    run_tasks_scenario();
    reset_design();

    // 'read pointer' bug detection
    rnd_scenario.set_probability( 0, 100, 0, 0);
    rnd_scenario.create_scenario( 1 );
    rnd_scenario.set_probability( 0, 0, 100, 0 );
    rnd_scenario.create_scenario( 1 );
    rnd_scenario.set_probability( 0, 100, 0, 0);
    rnd_scenario.create_scenario( 15 );
    rnd_scenario.set_probability( 0, 0, 100, 0);
    rnd_scenario.create_scenario( 15 );

    run_tasks_scenario();
    reset_design();

    // Simultaneous read and write while 1 word left for full
    rnd_scenario.set_probability( 0, 100, 0, 0 );
    rnd_scenario.create_scenario( 15 );
    rnd_scenario.set_probability( 0, 0, 0, 100);
    rnd_scenario.create_scenario( 16 );

    run_tasks_scenario();
    reset_design();

    // Simultaneous read and write while 1 word left for empty
    rnd_scenario.set_probability( 0, 0, 100, 0 );
    rnd_scenario.create_scenario( 1 );
    rnd_scenario.set_probability( 0, 0, 0, 100);
    rnd_scenario.create_scenario( 16 );

    run_tasks_scenario();
    reset_design();

    // 'Almost empty' flag bug detection
    rnd_scenario.set_probability( 0, 100, 0, 0);
    rnd_scenario.create_scenario( 15 );
    rnd_scenario.set_probability( 0, 0, 100, 0 );
    rnd_scenario.create_scenario( 15 );

    run_tasks_scenario();

    $display( "Test finished! Check 'log' result..." );
    $stop();
  end

endmodule
