import json, time, os, psutil
from celery import shared_task


# ---------------------------------------------------------------------
# Simple diagnostic task (optional)
# ---------------------------------------------------------------------
@shared_task
def hello_world(n):
    """Quick test task to monitor resource usage."""
    proc = psutil.Process(os.getpid())
    mem = proc.memory_info().rss / (1024 * 1024)
    cpu = proc.cpu_percent(interval=0.05)
    print(f"[Task {n}] PID={proc.pid} | MEM={mem:.2f}MB | CPU={cpu:.2f}%")
    time.sleep(0.01)
    return n
