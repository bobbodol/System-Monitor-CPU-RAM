// system_monitor.go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type Monitor struct {
	interval       int
	running        bool
	logging        bool
	showProcesses  bool
}

func NewMonitor(interval int) *Monitor {
	return &Monitor{
		interval: interval,
		running:  true,
	}
}

func getCPUUsage() (float64, error) {
	if runtime.GOOS == "windows" {
		// Using wmic to get CPU load
		cmd := exec.Command("wmic", "cpu", "get", "loadpercentage")
		out, err := cmd.Output()
		if err != nil {
			return 0, err
		}
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line != "" && line != "LoadPercentage" {
				val, err := strconv.ParseFloat(line, 64)
				if err == nil {
					return val, nil
				}
			}
		}
		return 0, nil
	} else {
		// Unix: use ps aux or /proc/stat (simplified: use ps for demo)
		// More accurate would be to read /proc/stat, but for simplicity we use 'ps' or 'top'
		cmd := exec.Command("sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
		out, err := cmd.Output()
		if err != nil {
			return 0, err
		}
		val, err := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
		if err != nil {
			return 0, err
		}
		return val, nil
	}
}

func getMemoryUsage() (total, used, free uint64, percent float64) {
	if runtime.GOOS == "windows" {
		// Windows: use wmic os get TotalVisibleMemorySize,FreePhysicalMemory
		cmd := exec.Command("wmic", "os", "get", "TotalVisibleMemorySize,FreePhysicalMemory")
		out, err := cmd.Output()
		if err != nil {
			return 0, 0, 0, 0
		}
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "TotalVisibleMemorySize") {
				continue
			}
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				totalKB, _ := strconv.ParseUint(fields[0], 10, 64)
				freeKB, _ := strconv.ParseUint(fields[1], 10, 64)
				total = totalKB * 1024
				free = freeKB * 1024
				used = total - free
				percent = float64(used) / float64(total) * 100
				return
			}
		}
	} else {
		// Unix: read /proc/meminfo
		data, err := os.ReadFile("/proc/meminfo")
		if err != nil {
			return 0, 0, 0, 0
		}
		lines := strings.Split(string(data), "\n")
		var memTotal, memAvailable uint64
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "MemTotal:") {
				fields := strings.Fields(line)
				if len(fields) >= 2 {
					memTotal, _ = strconv.ParseUint(fields[1], 10, 64)
					memTotal *= 1024 // KB to bytes
				}
			} else if strings.HasPrefix(line, "MemAvailable:") {
				fields := strings.Fields(line)
				if len(fields) >= 2 {
					memAvailable, _ = strconv.ParseUint(fields[1], 10, 64)
					memAvailable *= 1024
				}
			}
		}
		if memTotal > 0 {
			total = memTotal
			free = memAvailable
			used = total - free
			percent = float64(used) / float64(total) * 100
		}
	}
	return
}

func formatBar(percent float64, width int) string {
	filled := int(percent / 100 * float64(width))
	bar := strings.Repeat("█", filled) + strings.Repeat("░", width-filled)
	return bar
}

func (m *Monitor) render() {
	cpu, _ := getCPUUsage()
	total, used, free, percent := getMemoryUsage()
	totalGB := float64(total) / (1024 * 1024 * 1024)
	usedGB := float64(used) / (1024 * 1024 * 1024)

	fmt.Print("\033[H\033[2J") // clear screen
	fmt.Println("=== System Monitor ===")
	fmt.Printf("Refresh interval: %ds (press 'q' to quit, '+'/'-' to adjust, 'l' log, 'p' processes)\n\n", m.interval)
	cpuBar := formatBar(cpu, 30)
	memBar := formatBar(percent, 30)
	fmt.Printf("CPU:   %s  %5.1f%%\n", cpuBar, cpu)
	fmt.Printf("RAM:   %s  %5.1f%%  (Used: %.1f GB / Total: %.1f GB)\n", memBar, percent, usedGB, totalGB)

	if m.showProcesses {
		fmt.Println("\nTop processes by CPU:")
		// Placeholder: we won't implement full process list in Go for brevity
		fmt.Println("(Process list not implemented in this version)")
	}
}

func (m *Monitor) run() {
	fmt.Println("Starting System Monitor... (press 'q' to quit)")
	go func() {
		// Listen for keypresses (simple: just read from stdin)
		var b []byte = make([]byte, 1)
		for m.running {
			os.Stdin.Read(b)
			switch b[0] {
			case 'q':
				m.running = false
			case '+':
				if m.interval < 10 {
					m.interval++
				}
			case '-':
				if m.interval > 1 {
					m.interval--
				}
			case 'l':
				m.logging = !m.logging
				fmt.Println("\nLogging toggled.")
			case 'p':
				m.showProcesses = !m.showProcesses
			}
		}
	}()

	for m.running {
		m.render()
		time.Sleep(time.Duration(m.interval) * time.Second)
	}
	fmt.Println("Goodbye!")
}

func main() {
	monitor := NewMonitor(2)
	monitor.run()
}
