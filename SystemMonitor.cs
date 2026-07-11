// SystemMonitor.cs
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.IO;

class SystemMonitor
{
    private int interval;
    private bool running;
    private bool logging;
    private bool showProcesses;
    private StreamWriter logWriter;

    public SystemMonitor(int interval = 2)
    {
        this.interval = interval;
        running = true;
        logging = false;
        showProcesses = false;
    }

    private float GetCPUUsage()
    {
        // Simple: use PerformanceCounter if on Windows, else use /proc/stat (not cross-plat)
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            var counter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
            counter.NextValue();
            Thread.Sleep(100);
            return counter.NextValue();
        }
        else
        {
            // Linux / macOS: use 'top' or 'ps' (simplified)
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "sh",
                    Arguments = "-c \"top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1\"",
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                }
            };
            process.Start();
            string output = process.StandardOutput.ReadToEnd();
            process.WaitForExit();
            if (float.TryParse(output.Trim(), out float val))
                return val;
            return 0;
        }
    }

    private (float totalGB, float usedGB, float percent) GetMemoryUsage()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            var counter = new PerformanceCounter("Memory", "Available MBytes");
            float availableMB = counter.NextValue();
            float totalMB = (float)new Microsoft.VisualBasic.Devices.ComputerInfo().TotalPhysicalMemory / (1024 * 1024);
            float usedMB = totalMB - availableMB;
            float percent = (usedMB / totalMB) * 100;
            return (totalMB / 1024, usedMB / 1024, percent);
        }
        else
        {
            // Linux: read /proc/meminfo
            string[] lines = File.ReadAllLines("/proc/meminfo");
            long totalKB = 0, availableKB = 0;
            foreach (var line in lines)
            {
                if (line.StartsWith("MemTotal:"))
                    totalKB = long.Parse(line.Split(':')[1].Trim().Split(' ')[0]);
                else if (line.StartsWith("MemAvailable:"))
                    availableKB = long.Parse(line.Split(':')[1].Trim().Split(' ')[0]);
            }
            if (totalKB > 0)
            {
                float totalGB = totalKB / (1024f * 1024f);
                float usedGB = (totalKB - availableKB) / (1024f * 1024f);
                float percent = (usedGB / totalGB) * 100;
                return (totalGB, usedGB, percent);
            }
            return (0, 0, 0);
        }
    }

    private string FormatBar(float percent, int width = 30)
    {
        int filled = (int)(percent / 100 * width);
        return new string('█', filled) + new string('░', width - filled);
    }

    private void Render()
    {
        Console.Clear();
        float cpu = GetCPUUsage();
        var mem = GetMemoryUsage();
        string cpuBar = FormatBar(cpu);
        string memBar = FormatBar(mem.percent);
        Console.WriteLine("=== System Monitor ===");
        Console.WriteLine($"Refresh interval: {interval}s (press 'q' to quit, '+'/'-' to adjust, 'l' log, 'p' processes)");
        Console.WriteLine();
        Console.WriteLine($"CPU:   {cpuBar}  {cpu:F1}%");
        Console.WriteLine($"RAM:   {memBar}  {mem.percent:F1}%  (Used: {mem.usedGB:F1} GB / Total: {mem.totalGB:F1} GB)");

        if (showProcesses)
        {
            Console.WriteLine("\nTop processes by CPU:");
            // Placeholder: we'd need to query processes, skip for simplicity
            Console.WriteLine("(Process list not implemented in this version)");
        }

        if (logging)
        {
            if (logWriter == null)
            {
                logWriter = new StreamWriter("system_monitor.csv", true);
                logWriter.WriteLine("timestamp,cpu,mem_percent,mem_used_gb,mem_total_gb");
            }
            logWriter.WriteLine($"{DateTime.Now:yyyy-MM-dd HH:mm:ss},{cpu:F1},{mem.percent:F1},{mem.usedGB:F2},{mem.totalGB:F2}");
            logWriter.Flush();
        }
    }

    public void Run()
    {
        Console.WriteLine("Starting System Monitor... (press q to quit)");
        // Key listening (simple: read key in separate thread)
        var keyThread = new Thread(() =>
        {
            while (running)
            {
                var key = Console.ReadKey(true);
                if (key.KeyChar == 'q')
                {
                    running = false;
                }
                else if (key.KeyChar == '+')
                {
                    interval = Math.Min(interval + 1, 10);
                }
                else if (key.KeyChar == '-')
                {
                    interval = Math.Max(interval - 1, 1);
                }
                else if (key.KeyChar == 'l')
                {
                    logging = !logging;
                    if (logging) Console.WriteLine("\nLogging started.");
                    else Console.WriteLine("\nLogging stopped.");
                }
                else if (key.KeyChar == 'p')
                {
                    showProcesses = !showProcesses;
                }
            }
        });
        keyThread.IsBackground = true;
        keyThread.Start();

        while (running)
        {
            Render();
            Thread.Sleep(interval * 1000);
        }
        if (logWriter != null) logWriter.Close();
        Console.WriteLine("\nGoodbye!");
    }

    static void Main()
    {
        var monitor = new SystemMonitor(2);
        monitor.Run();
    }
}
