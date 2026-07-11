// system_monitor.js
const os = require('os');
const { exec } = require('child_process');
const readline = require('readline');

readline.emitKeypressEvents(process.stdin);
process.stdin.setRawMode(true);

class SystemMonitor {
    constructor(interval = 2) {
        this.interval = interval;
        this.running = true;
        this.logging = false;
        this.showProcesses = false;
    }

    getCPUUsage() {
        const cpus = os.cpus();
        let idle = 0, total = 0;
        cpus.forEach(cpu => {
            for (let type in cpu.times) {
                total += cpu.times[type];
            }
            idle += cpu.times.idle;
        });
        return { idle, total };
    }

    getMemoryUsage() {
        const total = os.totalmem();
        const free = os.freemem();
        const used = total - free;
        const percent = (used / total) * 100;
        return { total, used, free, percent };
    }

    getTopProcesses(callback) {
        const isWin = process.platform === 'win32';
        const cmd = isWin ? 'tasklist /fo csv /nh' : 'ps aux --sort=-%cpu | head -6';
        exec(cmd, (err, stdout) => {
            if (err) {
                callback([]);
                return;
            }
            const procs = [];
            const lines = stdout.split('\n');
            for (let line of lines) {
                if (!line.trim()) continue;
                if (isWin) {
                    const parts = line.split(',').map(s => s.trim().replace(/"/g, ''));
                    if (parts.length >= 5) {
                        const name = parts[0];
                        const pid = parseInt(parts[1]);
                        const mem = parseFloat(parts[4].replace(/,/g, '').replace('K', '')) / 1024;
                        procs.push({ pid, name, cpu: 0, mem });
                    }
                } else {
                    const fields = line.trim().split(/\s+/);
                    if (fields.length >= 11 && fields[0] !== 'USER') {
                        const pid = parseInt(fields[1]);
                        const cpu = parseFloat(fields[2]);
                        const mem = parseFloat(fields[3]);
                        const name = fields.slice(10).join(' ');
                        procs.push({ pid, name, cpu, mem });
                    }
                }
            }
            callback(procs.slice(0, 5));
        });
    }

    formatBar(percent, width = 30) {
        const filled = Math.round((percent / 100) * width);
        return '█'.repeat(filled) + '░'.repeat(width - filled);
    }

    render() {
        const cpu = this.getCPUUsage();
        const mem = this.getMemoryUsage();
        const memTotalGB = mem.total / 1024**3;
        const memUsedGB = mem.used / 1024**3;

        console.clear();
        console.log('=== System Monitor ===');
        console.log(`Refresh interval: ${this.interval}s (press 'q' to quit, '+'/'-' to adjust, 'l' log, 'p' processes)`);
        console.log();
        const cpuPercent = 100 - (cpu.idle / cpu.total * 100);
        const cpuBar = this.formatBar(cpuPercent);
        const memBar = this.formatBar(mem.percent);
        console.log(`CPU:   ${cpuBar}  ${cpuPercent.toFixed(1)}%`);
        console.log(`RAM:   ${memBar}  ${mem.percent.toFixed(1)}%  (Used: ${memUsedGB.toFixed(1)} GB / Total: ${memTotalGB.toFixed(1)} GB)`);

        if (this.showProcesses) {
            console.log('\nTop processes by CPU:');
            this.getTopProcesses((procs) => {
                if (procs.length === 0) {
                    console.log('(No data)');
                } else {
                    console.log('PID     NAME                 CPU%    MEM%');
                    procs.forEach(p => {
                        console.log(`${String(p.pid).padEnd(8)} ${p.name.slice(0, 20).padEnd(20)} ${String(p.cpu ? p.cpu.toFixed(1) : '0.0').padEnd(8)} ${String(p.mem ? p.mem.toFixed(1) : '0.0').padEnd(8)}`);
                    });
                }
            });
        }
    }

    run() {
        console.log('Starting System Monitor... (press q to quit)');
        process.stdin.on('keypress', (ch, key) => {
            if (key && key.name === 'q') {
                this.running = false;
                process.stdin.setRawMode(false);
                process.stdin.pause();
                console.log('\nGoodbye!');
                process.exit(0);
            }
            if (key && key.name === '+') {
                this.interval = Math.min(this.interval + 1, 10);
            }
            if (key && key.name === '-') {
                this.interval = Math.max(this.interval - 1, 1);
            }
            if (key && key.name === 'l') {
                this.logging = !this.logging;
                console.log('\nLogging toggled.');
            }
            if (key && key.name === 'p') {
                this.showProcesses = !this.showProcesses;
            }
        });

        const loop = () => {
            if (!this.running) return;
            this.render();
            setTimeout(loop, this.interval * 1000);
        };
        loop();
    }
}

const monitor = new SystemMonitor(2);
monitor.run();
