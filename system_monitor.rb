# system_monitor.rb
require 'io/console'
require 'timeout'

class SystemMonitor
  def initialize(interval = 2)
    @interval = interval
    @running = true
    @logging = false
    @show_processes = false
    @log_file = nil
  end

  def get_cpu_usage
    if RUBY_PLATFORM =~ /darwin/
      `ps -A -o %cpu | awk '{s+=$1} END {print s}'`.to_f
    elsif RUBY_PLATFORM =~ /linux/
      `top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1`.to_f
    elsif RUBY_PLATFORM =~ /mswin|mingw|windows/
      `wmic cpu get loadpercentage`.split("\n")[2].to_f
    else
      0.0
    end
  end

  def get_memory_usage
    if RUBY_PLATFORM =~ /darwin|linux/
      lines = File.readlines('/proc/meminfo') rescue []
      total_kb = nil
      avail_kb = nil
      lines.each do |line|
        if line.start_with?('MemTotal:')
          total_kb = line.split[1].to_f
        elsif line.start_with?('MemAvailable:')
          avail_kb = line.split[1].to_f
        end
      end
      if total_kb && avail_kb
        total_gb = total_kb / (1024.0 * 1024.0)
        used_gb = (total_kb - avail_kb) / (1024.0 * 1024.0)
        percent = used_gb / total_gb * 100
        return [total_gb, used_gb, percent]
      end
    elsif RUBY_PLATFORM =~ /mswin|mingw|windows/
      # Windows: use wmic
      output = `wmic os get TotalVisibleMemorySize,FreePhysicalMemory`
      lines = output.split("\n")
      if lines.size >= 2
        parts = lines[1].split
        total_kb = parts[0].to_f
        free_kb = parts[1].to_f
        total_gb = total_kb / (1024.0 * 1024.0)
        used_gb = (total_kb - free_kb) / (1024.0 * 1024.0)
        percent = used_gb / total_gb * 100
        return [total_gb, used_gb, percent]
      end
    end
    [0, 0, 0]
  end

  def format_bar(percent, width = 30)
    filled = (percent / 100.0 * width).round
    '█' * filled + '░' * (width - filled)
  end

  def render
    cpu = get_cpu_usage
    total_gb, used_gb, percent = get_memory_usage
    system('clear') || system('cls')
    puts "=== System Monitor ==="
    puts "Refresh interval: #{@interval}s (press 'q' to quit, '+'/'-' to adjust, 'l' log, 'p' processes)"
    puts
    cpu_bar = format_bar(cpu)
    mem_bar = format_bar(percent)
    puts "CPU:   #{cpu_bar}  #{cpu.round(1)}%"
    puts "RAM:   #{mem_bar}  #{percent.round(1)}%  (Used: #{used_gb.round(1)} GB / Total: #{total_gb.round(1)} GB)"

    if @show_processes
      puts "\nTop processes by CPU:"
      # Placeholder
      puts "(Process list not implemented in this version)"
    end

    if @logging
      unless @log_file
        @log_file = File.open('system_monitor.csv', 'a')
        @log_file.puts('timestamp,cpu,mem_percent,mem_used_gb,mem_total_gb') if File.size('system_monitor.csv') == 0
      end
      @log_file.puts("#{Time.now.iso8601},#{cpu.round(1)},#{percent.round(1)},#{used_gb.round(2)},#{total_gb.round(2)}")
      @log_file.flush
    end
  end

  def run
    puts "Starting System Monitor... (press q to quit)"
    Thread.new do
      while @running
        char = STDIN.getch
        case char
        when 'q'
          @running = false
        when '+'
          @interval = [@interval + 1, 10].min
        when '-'
          @interval = [@interval - 1, 1].max
        when 'l'
          @logging = !@logging
          puts "\nLogging toggled."
        when 'p'
          @show_processes = !@show_processes
        end
      end
    end

    while @running
      render
      sleep @interval
    end
    @log_file.close if @log_file
    puts "\nGoodbye!"
  end
end

SystemMonitor.new(2).run
