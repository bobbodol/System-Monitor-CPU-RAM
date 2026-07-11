📊 System Monitor – CPU & RAM

A lightweight **system monitor** that displays real‑time CPU and memory usage, with optional ASCII bar charts, process‑level details, and logging.  
Built in **7 programming languages** – perfect for system administration, learning, or quick performance checks.

## ✨ Features
- **CPU usage** – total and per‑core (where supported).
- **RAM usage** – total, used, free, and percentage.
- **Real‑time updates** – refresh interval configurable (default 2 seconds).
- **ASCII bar chart** – visual representation of CPU and memory load.
- **Top processes** – list processes by CPU or memory consumption.
- **Logging** – save metrics to a CSV file for later analysis.
- **Cross‑platform** – works on Linux, macOS, and Windows.

## 🗂 Languages & Files
| Language          | File                  |
|-------------------|-----------------------|
| Python            | `system_monitor.py`   |
| Go                | `system_monitor.go`   |
| JavaScript (Node) | `system_monitor.js`   |
| C#                | `SystemMonitor.cs`    |
| Java              | `SystemMonitor.java`  |
| Ruby              | `system_monitor.rb`   |
| Swift             | `system_monitor.swift`|

## 🚀 How to Run
Each file is standalone – run it with the appropriate interpreter/compiler:

| Language | Command |
|----------|---------|
| Python   | `python system_monitor.py` |
| Go       | `go run system_monitor.go` |
| JavaScript | `node system_monitor.js` |
| C#       | `dotnet run` (or `csc SystemMonitor.cs && SystemMonitor.exe`) |
| Java     | `javac SystemMonitor.java && java SystemMonitor` |
| Ruby     | `ruby system_monitor.rb` |
| Swift    | `swift system_monitor.swift` |

Some implementations may require additional dependencies (e.g., `psutil` for Python).  
See the code comments for details.

## 📊 Example Session
=== System Monitor ===
Refresh interval: 2s (press 'q' to quit)

CPU: ████████████████░░░░ 78.5%
RAM: ██████████░░░░░░░░░░ 45.2% (Used: 4.2 GB / Total: 8.0 GB)

Top processes by CPU:
PID NAME CPU%
1234 chrome 12.5
5678 code 5.2
...

text

## 🔧 Commands (Interactive)
| Key | Action |
|-----|--------|
| `q`  | Quit the monitor |
| `+`  | Increase refresh interval (slower) |
| `-`  | Decrease refresh interval (faster) |
| `l`  | Toggle logging on/off |
| `p`  | Toggle process list view |

## 🤝 Contributing
Add more metrics (disk, network), or a GUI version – PRs welcome!

## 📜 License
MIT – use freely.
