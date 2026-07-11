# system_monitor.py
import os
import sys
import time
import threading
import platform
import csv
from datetime import datetime

try:
    import psutil
except ImportError:
    print("Please install psutil: pip install psutil")
    sys.exit(1)

class SystemMonitor:
    def __init__(self, interval=2):
        self.interval = interval
        self.running = True
        self.logging = False
        self.log_file = None
        self.show_processes = False
        self.lock = threading.Lock()

    def get_cpu_usage(self):
        return psutil.cpu_percent(interval=0.1, percpu=False)

    def get_cpu_per_core(self):
        return psutil.cpu_percent(interval=0.1, percpu=True)

    def get_memory_usage(self):
        mem = psutil.virtual_memory()
        return {
            'total': mem.total,
            'used': mem.used,
            'free': mem.free,
            'percent': mem.percent
        }

    def get_top_processes(self, limit=5):
        procs = []
        for p in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
            try:
                info = p.info
                procs.append(info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        procs.sort(key=lambda x: x['cpu_percent'] or 0, reverse=True)
        return procs[:limit]

    def format_bar(self, percent, width=30):
        filled = int(width * percent / 100)
        bar = '█' * filled + '░' * (width - filled)
        return bar

    def render(self):
        cpu = self.get_cpu_usage()
        mem = self.get_memory_usage()
        mem_percent = mem['percent']
        mem_used_gb = mem['used'] / (1024**3)
        mem_total_gb = mem['total'] / (1024**3)

        os.system('cls' if platform.system() == 'Windows' else 'clear')
        print("=== System Monitor ===")
        print(f"Refresh interval: {self.interval}s (press 'q' to quit, '+'/'-' to adjust, 'l' to toggle log, 'p' to toggle processes)")
        print()
        cpu_bar = self.format_bar(cpu)
        mem_bar = self.format_bar(mem_percent)
        print(f"CPU:   {cpu_bar}  {cpu:5.1f}%")
        print(f"RAM:   {mem_bar}  {mem_percent:5.1f}%  (Used: {mem_used_gb:.1f} GB / Total: {mem_total_gb:.1f} GB)")

        if self.show_processes:
            print("\nTop processes by CPU:")
            procs = self.get_top_processes(5)
            print(f"{'PID':<8} {'NAME':<20} {'CPU%':<8} {'MEM%':<8}")
            for p in procs:
                print(f"{p['pid']:<8} {p['name'][:20]:<20} {p['cpu_percent'] or 0:<8.1f} {p['memory_percent'] or 0:<8.1f}")

        if self.logging:
            with self.lock:
                if self.log_file is None:
                    self.log_file = open('system_monitor.csv', 'w', newline='')
                    writer = csv.writer(self.log_file)
                    writer.writerow(['timestamp', 'cpu_percent', 'mem_percent', 'mem_used_gb', 'mem_total_gb'])
                else:
                    writer = csv.writer(self.log_file)
                writer.writerow([
                    datetime.now().isoformat(),
                    round(cpu, 1),
                    round(mem_percent, 1),
                    round(mem_used_gb, 2),
                    round(mem_total_gb, 2)
                ])
                self.log_file.flush()

    def run(self):
        print("Starting System Monitor... (press 'q' to quit)")
        # Use a separate thread to listen for keypresses
        def input_listener():
            while self.running:
                try:
                    ch = sys.stdin.read(1)
                    if ch == 'q':
                        self.running = False
                    elif ch == '+':
                        self.interval = min(self.interval + 1, 10)
                    elif ch == '-':
                        self.interval = max(self.interval - 1, 1)
                    elif ch == 'l':
                        self.logging = not self.logging
                        if self.logging:
                            print("\nLogging started.")
                        else:
                            print("\nLogging stopped.")
                            with self.lock:
                                if self.log_file:
                                    self.log_file.close()
                                    self.log_file = None
                    elif ch == 'p':
                        self.show_processes = not self.show_processes
                except:
                    pass

        thread = threading.Thread(target=input_listener, daemon=True)
        thread.start()

        while self.running:
            self.render()
            time.sleep(self.interval)

        if self.log_file:
            self.log_file.close()
        print("Goodbye!")

if __name__ == '__main__':
    monitor = SystemMonitor()
    monitor.run()
