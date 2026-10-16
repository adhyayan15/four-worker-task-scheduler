"""Interactive custom-input runner for the four-worker Verilog scheduler.

Place this file and user_tasks_tb.v beside your existing four Verilog modules.
Run: python run_tasks.py
"""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
MAX_TASKS = 256
SOURCE_FILES = [
    "busy_worker.v",
    "parallel_scheduler.v",
    "task_fifo.v",
    "queued_scheduler.v",
    "user_tasks_tb.v",
]


def main():
    print("4-WORKER SCHEDULER | CUSTOM TASKS")
    print("Enter two integers from 0 to 255 per task (e.g., 15 20).")
    print("Type 'run' to simulate all the entered tasks.\n")

    tasks = []
    while len(tasks) < MAX_TASKS:
        try:
            line = input(f"Task {len(tasks)+1} (A B / run): ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nCancelled.")
            return 1
        if line.lower() in {"run", "done"}:
            break
        parts = line.replace(",", " ").replace("+", " ").split()
        if len(parts) != 2:
            print("Enter exactly two numbers, such as: 15 20")
            continue
        try:
            a, b = map(int, parts)
        except ValueError:
            print("Numbers must be integers from 0 to 255.")
            continue
        if not (0 <= a <= 255 and 0 <= b <= 255):
            print("Each input must be between 0 and 255.")
            continue
        tasks.append((a, b))

    if not tasks:
        print("No tasks to run.")
        return 1

    missing = [name for name in SOURCE_FILES if not (ROOT / name).is_file()]
    if missing:
        print("Missing files in the project folder:", ", ".join(missing))
        return 1

    for tool in ("iverilog", "vvp"):
        if not shutil.which(tool):
            print(f"Cannot find {tool} on PATH. Restart VS Code and check MSYS2 PATH.")
            return 1

    (ROOT / "user_tasks.hex").write_text(
        "".join(f"{a:02x}{b:02x}\n" for a, b in tasks), encoding="ascii"
    )

    try:
        print("\nCompiling Verilog...")
        subprocess.run(
            ["iverilog", "-g2012", "-s", "user_tasks_tb", "-o", "interactive_sim.vvp", *SOURCE_FILES],
            cwd=ROOT, check=True,
        )
        print(f"\nRunning {len(tasks)} tasks through the hardware simulation...\n")
        subprocess.run(
            ["vvp", "interactive_sim.vvp", f"+n={len(tasks)}"],
            cwd=ROOT, check=True,
        )
    except subprocess.CalledProcessError as exc:
        print(f"Compile/simulation failed (exit code {exc.returncode}).")
        return exc.returncode or 1

    if shutil.which("gtkwave"):
        answer = input("\nOpen the waveform in GTKWave? (y/N): ").strip().lower()
        if answer in {"y", "yes"}:
            subprocess.Popen(["gtkwave", "interactive_wave.vcd"], cwd=ROOT)
    return 0


if __name__ == "__main__":
    sys.exit(main())