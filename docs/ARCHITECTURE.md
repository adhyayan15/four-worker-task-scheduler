# Architecture

## Datapath

`queued_scheduler.v` is the top-level hardware module:

1. `task_fifo.v`: stores up to **four 16-bit tasks** (two 8-bit operands).
2. `parallel_scheduler.v`: chooses one currently idle worker, scanning from a rotating two-bit pointer.
3. `busy_worker.v`: latches `A + B` as a **9-bit unsigned result** and waits a configured number of cycles before asserting `done`.

The default dispatcher instantiates four workers with `LATENCY=5`.

## Ready/valid protocol

At the **rising clock edge**, an input is accepted if both `in_valid` and `in_ready` are high. The producer must keep the task unchanged while offering it but waiting for `in_ready`. For the FIFO-to-scheduler interface, the oldest queued task transfers when `fifo_valid && scheduler_ready`.

The FIFO's `in_ready` is low whenever all four entries are full. This version does **not** permit a new insertion in a full FIFO in the same cycle that another item is popped; the producer retries on a later cycle.

## Dispatch algorithm

Starting at `next_worker`, the scheduler scans up to four workers and selects the first one whose `busy` bit is not asserted. Once a task is accepted for that worker, `next_worker` advances to the index after it (modulo four). Idle workers are skipped over only as needed.

Only **one task can enter the worker array each clock** even though up to four workers can be busy at once. There is no per-task ID in the hardware interface; results are observed per worker by `done_mask` and the corresponding nine-bit lane in `results`.

## Timing

Each worker accepts a new task at a rising edge (busy becomes 1), counts `LATENCY` processing cycles, then updates `result`, clears `busy`, and pulses `done` high for one cycle. This latency is deliberately modeled for scheduling experiments; it is **not** a multistage pipelined adder.

With `LATENCY=5`, the interactive test reports **six cycles from external FIFO acceptance to observed completion** for the first three-task workload, including a queue/dispatch handoff. This end-to-end latency depends on queueing and offered task traffic.

## Reset and limitations

The RTL uses a synchronous active-high reset for state. FIFO memory contents need not be initialized because data is valid only while `count > 0`.

This is a basic behavioral RTL design. It has not been synthesized or implemented on FPGA/ASIC hardware. A longer-run performance benchmark and timing closure remain future work.
