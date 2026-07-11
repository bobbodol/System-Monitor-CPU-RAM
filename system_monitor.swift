// system_monitor.swift
import Foundation

class SystemMonitor {
    var interval: Int
    var running: Bool
    var logging: Bool
    var showProcesses: Bool
    var logFile: FileHandle?

    init(interval: Int = 2) {
        self.interval = interval
        self.running = true
        self.logging = false
        self.showProcesses = false
    }

    func getCPUUsage() -> Double {
        // Use system commands (simplified)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["sh", "-c", "top -l1 | grep 'CPU usage' | awk '{print $3}' | cut -d'%' -f1"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return 0 }
        if let val = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return val
        }
        return 0
    }

    func getMemoryUsage() -> (totalGB: Double, usedGB: Double, percent: Double) {
        // Use sysctl for total, vm_stat for free
        var total: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &total, &size, nil, 0) == 0 {
            let totalGB = Double(total) / 1_073_741_824.0
            // Try to get free memory via vm_stat
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return (0,0,0) }
            let lines = output.split(separator: "\n")
            var freePages: UInt64 = 0
            for line in lines {
                if line.contains("Pages free:") {
                    let parts = line.split(separator: ":")
                    if parts.count > 1 {
                        freePages = UInt64(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                        break
                    }
                }
            }
            let pageSize = sysconf( _SC_PAGESIZE )
            let freeBytes = UInt64(freePages) * UInt64(pageSize)
            let usedBytes = total - freeBytes
            let usedGB = Double(usedBytes) / 1_073_741_824.0
            let percent = (Double(usedBytes) / Double(total)) * 100
            return (totalGB, usedGB, percent)
        }
        return (0,0,0)
    }

    func formatBar(percent: Double, width: Int = 30) -> String {
        let filled = Int((percent / 100.0) * Double(width))
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }

    func render() {
        let cpu = getCPUUsage()
        let mem = getMemoryUsage()
        let cpuBar = formatBar(percent: cpu)
        let memBar = formatBar(percent: mem.percent)
        // Clear screen
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        print("=== System Monitor ===")
        print("Refresh interval: \(interval)s (press 'q' to quit, '+'/'-' to adjust, 'l' log, 'p' processes)")
        print()
        print("CPU:   \(cpuBar)  \(String(format: "%.1f", cpu))%")
        print("RAM:   \(memBar)  \(String(format: "%.1f", mem.percent))%  (Used: \(String(format: "%.1f", mem.usedGB)) GB / Total: \(String(format: "%.1f", mem.totalGB)) GB)")

        if showProcesses {
            print("\nTop processes by CPU:")
            // Placeholder
            print("(Process list not implemented in this version)")
        }

        if logging {
            if logFile == nil {
                let path = FileManager.default.currentDirectoryPath + "/system_monitor.csv"
                if !FileManager.default.fileExists(atPath: path) {
                    try? "timestamp,cpu,mem_percent,mem_used_gb,mem_total_gb\n".write(toFile: path, atomically: true, encoding: .utf8)
                }
                logFile = FileHandle(forWritingAtPath: path)
                logFile?.seekToEndOfFile()
            }
            let line = "\(Date().iso8601String()),\(String(format: "%.1f", cpu)),\(String(format: "%.1f", mem.percent)),\(String(format: "%.2f", mem.usedGB)),\(String(format: "%.2f", mem.totalGB))\n"
            if let data = line.data(using: .utf8) {
                logFile?.write(data)
            }
        }
    }

    func run() {
        print("Starting System Monitor... (press q to quit)")
        // Set up stdin to not be line-buffered
        var oldTerm = termios()
        tcgetattr(STDIN_FILENO, &oldTerm)
        var newTerm = oldTerm
        newTerm.c_lflag &= ~UInt(ICANON)
        newTerm.c_lflag &= ~UInt(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &newTerm)

        DispatchQueue.global().async {
            while self.running {
                var ch: UInt8 = 0
                read(STDIN_FILENO, &ch, 1)
                let char = Character(UnicodeScalar(ch))
                switch char {
                case "q": self.running = false
                case "+": self.interval = min(self.interval + 1, 10)
                case "-": self.interval = max(self.interval - 1, 1)
                case "l": self.logging.toggle(); print("\nLogging toggled.")
                case "p": self.showProcesses.toggle()
                default: break
                }
            }
        }

        while running {
            render()
            Thread.sleep(forTimeInterval: TimeInterval(interval))
        }
        logFile?.closeFile()
        print("\nGoodbye!")
    }
}

extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

SystemMonitor().run()
