// SystemMonitor.java
import java.io.*;
import java.lang.management.*;
import java.util.*;
import java.util.concurrent.*;

public class SystemMonitor {
    private int interval;
    private volatile boolean running;
    private volatile boolean logging;
    private volatile boolean showProcesses;
    private PrintWriter logWriter;
    private Scanner scanner;

    public SystemMonitor(int interval) {
        this.interval = interval;
        this.running = true;
        this.logging = false;
        this.showProcesses = false;
        this.scanner = new Scanner(System.in);
    }

    private double getCPUUsage() {
        OperatingSystemMXBean osBean = ManagementFactory.getOperatingSystemMXBean();
        // Not all platforms support getSystemLoadAverage, fallback to using Runtime
        double load = osBean.getSystemLoadAverage();
        if (load < 0) {
            // Fallback: use a simple approximation (not accurate)
            return 0;
        }
        // Convert load to percentage: load average / number of cores * 100
        int cores = Runtime.getRuntime().availableProcessors();
        return (load / cores) * 100;
    }

    private double[] getMemoryUsage() {
        Runtime runtime = Runtime.getRuntime();
        long totalMem = runtime.totalMemory();
        long freeMem = runtime.freeMemory();
        long usedMem = totalMem - freeMem;
        double percent = (double) usedMem / totalMem * 100;
        double totalGB = totalMem / (1024.0 * 1024.0 * 1024.0);
        double usedGB = usedMem / (1024.0 * 1024.0 * 1024.0);
        return new double[]{totalGB, usedGB, percent};
    }

    private String formatBar(double percent, int width) {
        int filled = (int) (percent / 100 * width);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < filled; i++) sb.append('█');
        for (int i = filled; i < width; i++) sb.append('░');
        return sb.toString();
    }

    private void render() {
        System.out.print("\033[H\033[2J");
        System.out.flush();
        double cpu = getCPUUsage();
        double[] mem = getMemoryUsage();
        String cpuBar = formatBar(cpu, 30);
        String memBar = formatBar(mem[2], 30);
        System.out.println("=== System Monitor ===");
        System.out.printf("Refresh interval: %ds (press 'q' to quit, '+'/'-' to adjust, 'l' log, 'p' processes)\n\n", interval);
        System.out.printf("CPU:   %s  %5.1f%%\n", cpuBar, cpu);
        System.out.printf("RAM:   %s  %5.1f%%  (Used: %.1f GB / Total: %.1f GB)\n", memBar, mem[2], mem[1], mem[0]);

        if (showProcesses) {
            System.out.println("\nTop processes by CPU:");
            // Simplified: we can use jps or other, but for cross-platform we skip
            System.out.println("(Process list not implemented in this version)");
        }

        if (logging) {
            if (logWriter == null) {
                try {
                    logWriter = new PrintWriter(new FileWriter("system_monitor.csv", true));
                    logWriter.println("timestamp,cpu,mem_percent,mem_used_gb,mem_total_gb");
                } catch (IOException e) { }
            }
            if (logWriter != null) {
                logWriter.printf("%s,%.1f,%.1f,%.2f,%.2f\n",
                        new java.util.Date().toString(),
                        cpu, mem[2], mem[1], mem[0]);
                logWriter.flush();
            }
        }
    }

    public void run() {
        System.out.println("Starting System Monitor... (press q to quit)");
        // Key listener thread
        Thread keyThread = new Thread(() -> {
            while (running) {
                try {
                    if (System.in.available() > 0) {
                        char ch = (char) System.in.read();
                        if (ch == 'q') {
                            running = false;
                        } else if (ch == '+') {
                            interval = Math.min(interval + 1, 10);
                        } else if (ch == '-') {
                            interval = Math.max(interval - 1, 1);
                        } else if (ch == 'l') {
                            logging = !logging;
                            if (logging) System.out.println("\nLogging started.");
                            else System.out.println("\nLogging stopped.");
                        } else if (ch == 'p') {
                            showProcesses = !showProcesses;
                        }
                    }
                    Thread.sleep(100);
                } catch (Exception e) { }
            }
        });
        keyThread.setDaemon(true);
        keyThread.start();

        while (running) {
            render();
            try {
                Thread.sleep(interval * 1000);
            } catch (InterruptedException e) { break; }
        }
        if (logWriter != null) logWriter.close();
        System.out.println("\nGoodbye!");
    }

    public static void main(String[] args) {
        SystemMonitor monitor = new SystemMonitor(2);
        monitor.run();
    }
}
