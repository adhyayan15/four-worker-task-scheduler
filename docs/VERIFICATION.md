# Verification guide

Tests use Icarus Verilog and self-checking testbenches; a failing assertion terminates simulation using `$fatal`. Run from the **repository root**.

| Test | Coverage |
| --- | --- |
| `tests/busy_worker_tb.v` | Worker busy interval, ignores tasks while occupied, correct 9-bit result, reuse |
| `tests/task_fifo_tb.v` | Ordering, full/empty states, blocked pushes, simultaneous push/pop, pointer wraparound |
| `tests/parallel_scheduler_tb.v` | Four simultaneous busy workers, fifth-task rejection, independent completion, reuse |
| `tests/queued_scheduler_tb.v` | Twenty tasks, FIFO order, parallel execution, backpressure and reuse |
| `user_tasks_tb.v` | Arbitrary user-input operands, FIFO order, verified result, latency/utilization statistics |

### Commands

```bash
iverilog -g2012 -s busy_worker_tb -o busy_sim.vvp busy_worker.v tests/busy_worker_tb.v
vvp busy_sim.vvp

iverilog -g2012 -s task_fifo_tb -o fifo_sim.vvp task_fifo.v tests/task_fifo_tb.v
vvp fifo_sim.vvp

iverilog -g2012 -s parallel_scheduler_tb -o parallel_sim.vvp busy_worker.v parallel_scheduler.v tests/parallel_scheduler_tb.v
vvp parallel_sim.vvp

iverilog -g2012 -s queued_scheduler_tb -o queued_sim.vvp busy_worker.v parallel_scheduler.v task_fifo.v queued_scheduler.v tests/queued_scheduler_tb.v
vvp queued_sim.vvp
```

For custom inputs use `python run_tasks.py`. The runner writes `user_tasks.hex` and invokes the `user_tasks_tb` top-level testbench with `+n=N`.

To reproduce the earlier basic round-robin design:

```bash
iverilog -g2012 -s four_worker_scheduler_tb -o round_robin_sim.vvp examples/scheduler.v examples/four_worker_scheduler.v examples/four_worker_scheduler_tb.v
vvp round_robin_sim.vvp
```

The interactive runner and tests produce `.vvp` and `.vcd` outputs that are excluded from Git tracking by `.gitignore`.
