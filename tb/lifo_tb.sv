`timescale 1ns / 1ps

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

logic [DWIDTH - 1 : 0] lifo_data [$];

event event1, event2;

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

task automatic single_write();
  wait( !full_o );
  wait( event2.triggered );
  wrreq_i = 1'b1;
  data_i  = $random;
  @( posedge clk_i );
  wait( event2.triggered );
  wrreq_i = 1'b0;
endtask : single_write

task automatic single_read();
  wait( !empty_o );
  wait( event2.triggered );
  rdreq_i = 1'b1;
  @( posedge clk_i );
  wait( event2.triggered );
  rdreq_i = 1'b0;
endtask : single_read

task automatic write_full_lifo( input bit pause_enable );
  fork : write_loop
    wait( full_o );
    while( 1 )
      begin
        wait( event2.triggered );
        if( pause_enable )
          wrreq_i = $urandom_range( 1 );
        else
          wrreq_i = 1'b1;
        data_i  = $random;
        @( posedge clk_i );
      end
  join_any
  disable write_loop;
  wait( event2.triggered );
  wrreq_i = 1'b0;
endtask : write_full_lifo

task automatic read_full_lifo( input bit pause_enable );
  fork : read_loop
    wait( empty_o );
    while( 1 )
      begin
        wait( event2.triggered );
        if( pause_enable )
          rdreq_i = $urandom_range( 1 );
        else
          rdreq_i = 1'b1;
        @( posedge clk_i );
      end
  join_any
  disable read_loop;
  wait( event2.triggered );
  rdreq_i = 1'b0;
endtask : read_full_lifo

task automatic full_flag_bound_test();
  write_full_lifo( 0 );
  single_read();
  single_write();
  single_read();
  single_write();
endtask : full_flag_bound_test

task automatic empty_flag_bound_test();
  read_full_lifo( 0 );
  single_write();
  single_read();
  single_write();
  single_read();
endtask : empty_flag_bound_test


task automatic control_signals_check();
  int cnt = 0;
  forever
    begin
      @( posedge clk_i );
      if( cnt !== usedw_o )
        begin
          $display( "%0t : Unexpected usedw value", $time );
          $display( "Expected : %d", cnt );
          $display( "Observed : %d", usedw_o );
          $stop();
        end
      if( ( cnt == LIFO_DEPTH ) && ( !full_o ) )
        begin
          $display( "%0t : Unexpected full flag behavior", $time );
          $display( "Expected : 1" );
          $display( "Observed : 0" );
          $stop();
        end
      else if( ( cnt !== LIFO_DEPTH ) && full_o )
        begin
          $display( "%0t : Unexpected full flag behavior", $time );
          $display( "Expected : 0" );
          $display( "Observed : 1" );
          $stop();
        end
      if( ( cnt == 0 ) && ( !empty_o ) )
        begin
          $display( "%0t : Unexpected empty flag behavior", $time );
          $display( "Expected : 1" );
          $display( "Observed : 0" );
          $stop();
        end
      else if( ( cnt !== 0 ) && empty_o )
        begin
          $display( "%0t : Unexpected empty flag behavior", $time );
          $display( "Expected : 0" );
          $display( "Observed : 1" );
          $stop();
        end
      if( wrreq_i )
        cnt = cnt + 1;
      else if( rdreq_i )
        cnt = cnt - 1;
      if( wrreq_i )
        lifo_data.push_back( data_i );
      -> event1;
    end
endtask : control_signals_check

task automatic data_check();
  logic [DWIDTH - 1 : 0] temp_data;
  forever
    begin
      @( posedge clk_i );
      wait( event1.triggered );
      if( rdreq_i )
        do
          begin
            temp_data = lifo_data.pop_back();
            -> event2;
            @( posedge clk_i );
            wait( event1.triggered );
            if( temp_data !== q_o )
              begin
                $display( "%0t : Data word mismatch", $time );
                $display( "Expected : %h", temp_data );
                $display( "Observed : %h", q_o );
                $stop();
              end
          end
        while( rdreq_i );
      -> event2;
    end
endtask : data_check

always #5 clk_i = !clk_i;


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

    fork
      control_signals_check();
      data_check();
    join_none;

    // full and empty flags test
    write_full_lifo( 0 );
    read_full_lifo( 0 );
    repeat(5) @( posedge clk_i );
    
    write_full_lifo( 1 );
    read_full_lifo( 1 );
    repeat(5) @( posedge clk_i );

    // full and empty bound condition test
    full_flag_bound_test();
    repeat(5) @( posedge clk_i );

    empty_flag_bound_test();
    repeat(5) @( posedge clk_i );

    $display( "Test successfully passed" );
    $stop();
  end

endmodule : lifo_tb