LOGFILE = "tmp/rclc_sub.log"

def modify_log(lines)
  new_lines = []

  group = nil

  lines.each { |line|
    if group
      if m = line.match(/^@end /)
        group = nil
      else
        new_lines << "#{group}__#{line}"
      end
    else
      if m = line.match(/^@beg (.+)/)
        group = m[1]
      else
        new_lines << line
      end
    end
  }

  new_lines
end

def format_time(float_sec)
  int_sec, mod = float_sec.divmod(1)
  msec = (mod * 1000).round
  min, sec = int_sec.divmod(60)
  format("%dm %02d.%03ds", min, sec, msec)
end

def print_time(map, name)
  key_beg = (name + "_beg").to_sym
  key_end = (name + "_end").to_sym
  t_beg = map[key_beg]
  t_end = map[key_end]
  puts format(
         "%-20s %s",
         name,
         format_time(t_end - t_beg)
       )
end

def print_times
  log_lines =
    File.read(LOGFILE).split("\n---\n").last.lines.to_a
      .reject { |line| line.start_with?("# ") }
      .reject { |line| /^\s*$/ =~ line }

  log_lines = modify_log(log_lines)

  map = {}

  log_lines.each { |line|
    parts = line.strip.split(" ")
    if parts.size == 2
      map[parts[0].to_sym] = parts[1].to_f
    end
  }

  puts "----"
  %w(lexer parser codegen).each { |stage|
    print_time(map, "rcl_#{stage}")
    %w(lexer parser codegen).each{ |stagesub|
      print "    "
      print_time(map, "rcl_#{stage}__#{stagesub}")
    }
  }

  puts "----"
  print_time(map, "test_selfhost")
end

case ARGV[0]
when "print-times"
  print_times
else
  raise "unknown command"
end
