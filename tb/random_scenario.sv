class random_scenario;

int idle_probability;
int wo_probability;
int ro_probability;
int rw_probability;

rand bit [1:0] task_num;
constraint task_num_constraint {
  task_num dist {
    0 := idle_probability,
    1 := wo_probability,
    2 := ro_probability,
    3 := rw_probability
  };
}

bit [1:0] tasks_scenario [$];

function automatic void set_probability(
  int idle_probability = 30,
  int wo_probability   = 30,
  int ro_probability   = 30,
  int rw_probability   = 30
);
  this.idle_probability = idle_probability;
  this.wo_probability   = wo_probability;
  this.ro_probability   = ro_probability;
  this.rw_probability   = rw_probability;
endfunction

task automatic create_scenario( input int tasks_amount );
  repeat( tasks_amount )
    begin
      assert( randomize() );
      tasks_scenario.push_back( task_num );
    end
endtask

task automatic get_scenario( output bit [1:0] tasks_scenario [$] );
  tasks_scenario = this.tasks_scenario;
  this.tasks_scenario.delete();
endtask

endclass
