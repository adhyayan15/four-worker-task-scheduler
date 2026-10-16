# Simulation performance and interpretation

## Recorded example: three custom tasks

Inputs: `22 33`, `22 33`, `89 73`. In the recorded interactive run:

| Measurement | Value |
| --- | --- |
| Tasks accepted / dispatched / completed | **3 / 3 / 3** |
| Results | **55, 55, 162** |
| Elapsed | **9 simulated cycles / 90 ns** |
| Average end-to-end latency | **6.00 cycles / 60 ns** |
| Throughput, assuming 100 MHz | **33.33 million tasks/s** |
| Average worker utilization | **41.7%** |
| Peak FIFO occupancy | **1 / 4** |
| Backpressure | **0 cycles** |

The 100 MHz frequency is a testbench assumption (`always #5 clk = ~clk`, `timescale 1ns/1ps`), **not a measured target-clock limit**.

## What the metrics mean

- **Throughput** = completed tasks / (last-completion minus first-acceptance interval). This workload-window value changes with the test length.
- **Latency** = each task's completion clock minus its input acceptance clock.
- **Worker utilization** = observed busy worker-cycles divided by four times the active measurement interval.
- **Peak FIFO occupancy** = largest number of waiting task entries.
- **Backpressure** = clock cycles when `in_valid` was high and `in_ready` was low.

A three-task workload cannot establish **sustained throughput**. For more representative numbers, run dozens or hundreds of tasks and compare different arrival patterns. The interactive runner allows up to 256 tasks.

## Recorded 20-task integration test

The uploaded `queued_wave.vcd` trace records all **20 tasks accepted, dispatched, and completed**. The associated testbench checks FIFO order, results, simultaneous busy workers, backpressure, and reuse.

## What is not measured

No post-synthesis utilization, FPGA maximum frequency, static timing analysis, silicon energy, or actual wall-clock accelerator performance. In particular, this Verilog design does not run on NVIDIA GPU hardware.

## Reproduce the waveform

```bash
python run_tasks.py
# Enter input pairs, then 'run'
gtkwave interactive_wave.vcd
```

In GTKWave, expand `user_tasks_tb -> dut` to inspect `queue_count`, `busy_mask`, `done_mask`, and `results`. Expand `scheduler` for `dispatch` and `next_worker`.
