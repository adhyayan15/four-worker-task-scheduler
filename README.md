# Four-Worker Task Scheduler

### Learning how to schedule work in hardware, one clock cycle at a time

I built this because I wanted to understand what **parallel execution** looks like at the RTL level, not just in a Python program.

I started with a single Verilog worker that added two numbers. Then I made four copies and rotated incoming tasks between them. That worked, but it wasn't very interesting: the workers finished almost immediately, so there was no real decision to make about who was free.

The project got more interesting when I gave each worker a **busy state** and a simulated processing delay. Now the scheduler needed to find an available worker. And when all four were busy, I needed somewhere for new tasks to wait. That's why I added the FIFO.

## What it does now

```text
               New tasks (A, B)
                       |
                  4-slot FIFO
                       |
           Busy-aware round robin
              /    /    \    \
             W0   W1    W2   W3
              \    \    /    /
             Individual results
```

Each worker currently performs **8-bit unsigned addition**, producing a **9-bit result**. I used addition to keep the computation simple and focus on scheduling, handshakes, and verifying what happens over time.

The system has:

- **Four independent workers** that can all be busy at the same time.
- **Round-robin selection** that skips workers already processing something.
- **A four-entry FIFO** so incoming tasks can wait their turn.
- **Ready/valid signals** so a sender knows when the queue is full.
- **Done and busy masks** to inspect worker activity in simulation.

Only one new task can be dispatched per clock cycle. The workers model a five-cycle busy interval; they're **not** five-stage pipelined adders.

## The part I liked testing

At first, I was just checking whether `15 + 20` came back as `35`. Later I was watching all four `busy` bits go high in GTKWave, sending another task, and checking that the scheduler held it in the queue instead of losing it.

The [integration testbench](tests/queued_scheduler_tb.v) exercised **20 tasks**, including FIFO ordering, blocked inputs, worker reuse, and overlapping execution. All 20 were accepted, dispatched, and completed in that run.

I also wrote a Python runner so you don't have to edit Verilog every time you want to try different numbers.

## Try your own tasks

You'll need **Python 3** and **Icarus Verilog**. GTKWave is optional but useful for seeing the clock-by-clock behavior. I used VS Code on Windows with MSYS2 UCRT64.

If you need Icarus Verilog and GTKWave in MSYS2:

```bash
pacman -S mingw-w64-ucrt-x86_64-iverilog mingw-w64-ucrt-x86_64-gtkwave
```

Then, from a terminal that can find `iverilog` and `vvp`:

```bash
git clone https://github.com/adhyayan15/four-worker-task-scheduler.git
cd four-worker-task-scheduler
python run_tasks.py
```

Example session:

```text
Task 1 (A B / run): 22 33
Task 2 (A B / run): 22 33
Task 3 (A B / run): 89 73
Task 4 (A B / run): run
```

The program compiles the Verilog, checks the returned sums, reports simulation metrics, and offers to open the waveform in GTKWave. Enter up to **256 tasks**, with numbers from **0 to 255**.

## Numbers from one example run

For the three tasks above:

| Measured in simulation | Result |
| --- | ---: |
| Tasks completed correctly | 3 / 3 |
| Average input-to-completion latency | 6 clock cycles (60 ns) |
| Elapsed workload interval | 9 cycles (90 ns) |
| Average worker utilization | 41.7% |
| Peak queue depth | 1 of 4 |
| Backpressure | 0 cycles |

The script also reports **33.33 million tasks/sec at an assumed 100 MHz clock** for that short example. That is *not* FPGA-measured throughput and definitely not a sustained real-hardware benchmark. I haven't synthesized this design or run it on a physical FPGA.

## Looking through the code

If you're new to Verilog, these are the useful files to open in order:

1. [busy_worker.v](busy_worker.v) — one worker with a result, busy flag, and completion signal.
2. [parallel_scheduler.v](parallel_scheduler.v) — chooses which worker gets the next task.
3. [task_fifo.v](task_fifo.v) — stores tasks when they can't be dispatched yet.
4. [queued_scheduler.v](queued_scheduler.v) — connects the queue to the scheduler.
5. [user_tasks_tb.v](user_tasks_tb.v) and [run_tasks.py](run_tasks.py) — the interactive simulation.

I kept my [earlier experiments](examples/) too, so it's possible to follow how the design changed. The [testbenches](tests/) cover individual modules and the complete system.

For manual compile/run commands and more detail, see [verification](docs/VERIFICATION.md), [architecture](docs/ARCHITECTURE.md), and [performance notes](docs/PERFORMANCE.md). The repository also includes a GitHub Actions test workflow.

## What I'd improve

The workers only add numbers right now. Next I'd like to support different operations, run larger and more varied workloads, and synthesize the RTL so I can see how much actual hardware it needs.

What this project really taught me is that distributing tasks isn't just picking a worker. You also have to decide **when a task is accepted, what happens when everything is busy, and how to prove no result got lost**.

Built by **Adhyayan Tiwari**.
