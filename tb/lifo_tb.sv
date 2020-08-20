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

int   ctrl_cnt = 0;

event ctrl_signals_checked;
event data_checked;

task automatic write_only();

  if( ctrl_cnt !== LIFO_DEPTH )
    begin
      wait( data_checked.triggered );
      wrreq_i = 1'b1;
      data_i  = $random;
      lifo_data.push_back( data_i );
      @( posedge clk_i );
      wait( data_checked.triggered );
      wrreq_i = 1'b0;
    end
  else
    idle();

endtask : write_only

task automatic read_only();

  if( ctrl_cnt !== 0 )
    begin
      wait( data_checked.triggered );
      rdreq_i = 1'b1;
      @( posedge clk_i );
      wait( data_checked.triggered );
      rdreq_i = 1'b0;
    end
  else
    idle();

endtask : read_only

task automatic idle();

  @( posedge clk_i );

endtask : idle

task automatic run_tasks_scenario ( input bit [1:0] tasks_scenario[$] );

  bit [1:0] current_task;
  while( tasks_scenario.size() !== 0 )
    begin
      current_task = tasks_scenario.pop_front();
      if( current_task == 0 )
        idle();
      else if( current_task == 1 )
        write_only();
      else if( current_task == 2 )
        read_only();
    end

endtask : run_tasks_scenario

task automatic control_signals_check();

  forever
    begin
      @( posedge clk_i );
      if( ctrl_cnt !== usedw_o )
        begin
          $display( "%0t : Unexpected usedw value", $time );
          $display( "Expected : %d", ctrl_cnt );
          $display( "Observed : %d", usedw_o );
          $stop();
        end
      if( ( ctrl_cnt == LIFO_DEPTH ) && ( !full_o ) )
        begin
          $display( "%0t : Unexpected full flag behavior", $time );
          $display( "Expected : 1" );
          $display( "Observed : 0" );
          $stop();
        end
      else if( ( ctrl_cnt !== LIFO_DEPTH ) && full_o )
        begin
          $display( "%0t : Unexpected full flag behavior", $time );
          $display( "Expected : 0" );
          $display( "Observed : 1" );
          $stop();
        end
      if( ( ctrl_cnt == 0 ) && ( !empty_o ) )
        begin
          $display( "%0t : Unexpected empty flag behavior", $time );
          $display( "Expected : 1" );
          $display( "Observed : 0" );
          $stop();
        end
      else if( ( ctrl_cnt !== 0 ) && empty_o )
        begin
          $display( "%0t : Unexpected empty flag behavior", $time );
          $display( "Expected : 0" );
          $display( "Observed : 1" );
          $stop();
        end
      if( wrreq_i )
        ctrl_cnt = ctrl_cnt + 1;
      else if( rdreq_i )
        ctrl_cnt = ctrl_cnt - 1;
      -> ctrl_signals_checked;
    end

endtask : control_signals_check

task automatic data_check();

  logic [DWIDTH - 1 : 0] temp_data;
  forever
    begin
      @( posedge clk_i );
      wait( ctrl_signals_checked.triggered );
      if( rdreq_i )
        do
          begin
            temp_data = lifo_data.pop_back();
            -> data_checked;
            @( posedge clk_i );
            wait( ctrl_signals_checked.triggered );
            if( temp_data !== q_o )
              begin
                $display( "%0t : Data word mismatch", $time );
                $display( "Expected : %h", temp_data );
                $display( "Observed : %h", q_o );
                $stop();
              end
          end
        while( rdreq_i );
      -> data_checked;
    end

endtask : data_check

always #5 clk_i = !clk_i;

random_scenario scenario;

initial
  begin
    $timeformat( -9, 0, " ns", 20 );
    wrreq_i = 1'b0;
    data_i  = '0;
    rdreq_i = 1'b0;

    @( posedge clk_i );
    srst_i = 1'b1;
    @( posedge clk_i );
    srst_i = 1'b0;

    repeat(5) @( posedge clk_i );

    fork
      control_signals_check();
      data_check();
    join_none;

    scenario = new();
    scenario.set_probability(0, 100, 0, 0);
    scenario.get_tasks_scenario( 20 );
    run_tasks_scenario( scenario.tasks_scenario );
    repeat(5) @( posedge clk_i );

    scenario = new();
    scenario.set_probability(0, 0, 100, 0);
    scenario.get_tasks_scenario( 20 );
    run_tasks_scenario( scenario.tasks_scenario );
    repeat(5) @( posedge clk_i );
 
    scenario = new(); 
    scenario.set_probability(0, 70, 30, 0);
    scenario.get_tasks_scenario( 30 );
    run_tasks_scenario( scenario.tasks_scenario );
    repeat(5) @( posedge clk_i );

    scenario = new(); 
    scenario.set_probability(0, 30, 70, 0);
    scenario.get_tasks_scenario( 30 );
    run_tasks_scenario( scenario.tasks_scenario );
    repeat(5) @( posedge clk_i );

    $display( "Test successfully passed" );
    $stop();
  end

endmodule : lifo_tb