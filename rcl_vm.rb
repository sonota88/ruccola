require "pp"
require "json"

require_relative "common"

module TermColor
  RESET  = "\e[m"
  RED    = "\e[0;31m"
  BLUE   = "\e[0;34m"
end

class Memory
  attr_accessor :code
  attr_reader :data, :vram

  CODE_DUMP_WIDTH = 10

  def initialize(data_size)
    @code = []
    @data = Array.new(data_size, 0)
    @vram = Array.new(50, 0)
  end

  def label?(insn)
    insn[0] == :_cmt && insn[1].start_with?("label:")
  end

  def dump_code(pc)
    work_insns = []
    @code.each_with_index do |insn, i|
      work_insns << { addr: i, insn: insn }
    end

    work_insns
      .select do |work_insn|
        pc - CODE_DUMP_WIDTH <= work_insn[:addr] &&
          work_insn[:addr] <= pc + CODE_DUMP_WIDTH
      end
      .map do |work_insn|
        head =
          if work_insn[:addr] == pc
            "pc =>"
          else
            "     "
          end

        opcode = work_insn[:insn][0]

        color =
          case opcode
          when "exit", "call", "ret", "jump", "jump_eq", "jump_g"
            TermColor::RED
          when "_cmt", "_debug"
            TermColor::BLUE
          else
            ""
          end

        indent =
          if label?(work_insn[:insn])
            ""
          else
            "  "
          end

        format(
          "%s %02d #{color}%s%s#{TermColor::RESET}",
          head,
          work_insn[:addr],
          indent,
          work_insn[:insn].inspect
        )
      end
      .join("\n")
  end

  def _chr(n)
    if n.nil?
      return "! nil"
    end
    unless n.is_a?(Integer)
      return "! non-integer"
    end

    if n < 32
      if n == 12
        "LF"
      else
        "ctrl"
      end
    elsif 32 <= n && n < 128
      "'#{n.chr}'"
    else
      ""
    end
  end

  def dump_data(sp, bp)
    lines = []
    @data.each_with_index do |x, i|
      addr = i
      next if addr < sp - 12
      next if addr > sp + 8

      head =
        case addr
        when sp
          if sp == bp
            "sp bp => "
          else
            "sp    => "
          end
        when bp
          "   bp => "
        else
          "         "
        end
      begin
        lines << head + format("%04d % 4d %s", addr, x, _chr(x))
      rescue => e
        lines << [e.message, { x: x }].inspect
      end
    end
    lines.join("\n")
  end

  def format_cols(cols)
    cols.map {|col| col == 1 ? "@" : "." }.join("")
  end

  def dump_vram
    rows = @vram.each_slice(5).to_a
    main = rows[0..4]
    buf = rows[5..9]

    (0..4)
      .map do |li| # line index
        format_cols(main[li]) + " " + format_cols(buf[li])
      end
      .join("\n")
  end
end

class Vm
  FLAG_TRUE = 1
  FLAG_FALSE = 0
  EOF = -1

  def initialize(mem, data_size, debug, verbose, skip)
    @debug = debug

    @verbose =
      if @debug
        true
      else
        verbose
      end

    @skip = skip

    @pc = 0 # program counter

    # registers
    @reg_a = 0
    @reg_b = 0

    @zf = FLAG_FALSE # zero flag
    @sf = FLAG_FALSE # sign flag

    @mem = mem
    @sp = data_size - 1 # stack pointer
    @bp = data_size - 1 # base pointer

    @step = 0

    @output = ""
  end

  def set_sp(addr)
    if addr < 0
      dump_at_exit()
      raise "Stack overflow"
    end

    @sp = addr
  end

  def load_program_file(path)
    insns = File.open(path).each_line.map { |line| JSON.parse(line) }
    load_program(insns)
  end

  def load_program(insns)
    @mem.code = insns
      .map do |insn|
        opcode, *operands = insn
        [opcode.to_sym, *operands]
      end
  end

  def execute
    insn = @mem.code[@pc]

    opcode = insn[0]

    case opcode
    when :exit     then return @mem.code[@pc][1]
    when :cp       then cp()       ; @pc += 1
    when :lea      then lea()      ; @pc += 1
    when :add_ab   then add_ab()   ; @pc += 1
    when :mult_ab  then mult_ab()  ; @pc += 1
    when :add_sp   then add_sp()   ; @pc += 1
    when :sub_sp   then sub_sp()   ; @pc += 1
    when :compare  then compare()  ; @pc += 1
    when :jump     then jump()
    when :jump_eq  then jump_eq()
    when :jump_g   then jump_g()
    when :call     then call()
    when :ret      then ret()
    when :push     then push()     ; @pc += 1
    when :pop      then pop()      ; @pc += 1
    when :read     then read()     ; @pc += 1
    when :write    then write()    ; @pc += 1
    when :set_vram then set_vram() ; @pc += 1
    when :get_vram then get_vram() ; @pc += 1
    when :_cmt     then              @pc += 1
    when :_debug   then _debug()   ; @pc += 1
    else
      raise "Unknown opcode (#{opcode})"
    end

    nil
  end

  def start
    dump() # 初期状態
    if @debug
      $stderr.puts "Press enter key to start"
      $stdin.gets
    end

    loop do
      @step += 1

      exit_status = execute()
      if exit_status
        dump()
        $stderr.puts "exit" if @verbose
        return exit_status
      end

      dump() if @step % @skip == 0
      $stdin.gets if @debug
    end
  end

  def dump_reg
    [
      "reg_a(#{ @reg_a.inspect })",
      "reg_b(#{ @reg_b.inspect })"
    ].join(" ")
  end

  def dump
    return unless @verbose

    $stderr.puts <<~DUMP
      ================================
      #{ @step }: #{ dump_reg() } zf(#{ @zf }) sf(#{ @sf })
      ---- memory (code) ----
      #{ @mem.dump_code(@pc) }
      ---- memory (data) ----
      #{ @mem.dump_data(@sp, @bp) }
      ---- memory (vram) ----
      #{ @mem.dump_vram() }
      ---- output ----
      #{ @output.inspect }
    DUMP
  end

  def dump_for_test
    puts "reg_a (#{@reg_a})"
    puts "reg_b (#{@reg_b})"
    puts "pc (#{@pc})"
    puts "bp (#{@bp})"
    puts "sp (#{@sp})"
    puts "zf (#{@zf})"
    puts "sf (#{@sf})"
  end

  def get_value(operand)
    case operand
    when "reg_a"   then @reg_a
    when "reg_b"   then @reg_b
    when "bp"      then @bp
    when "sp"      then @sp
    when /^-?\d+$/ then operand.to_i
    when /^mem:/   then @mem.data[calc_indirect_addr(operand)]
    else
      raise panic("operand", operand)
    end
  end

  def set_value(dest, val)
    case dest
    when String
      case dest
      when "reg_a" then @reg_a = val
      when "reg_b" then @reg_b = val
      when "bp"    then @bp    = val
      when "sp"    then @sp    = val
      when /^mem:/ then @mem.data[calc_indirect_addr(dest)] = val
      else
        raise panic("dest", dest)
      end
    else
      raise panic("dest", dest)
    end
  end

  def calc_indirect_addr(str)
    _, base_str, disp_str, index_str = str.split(":")

    base  = get_value(base_str)
    disp  = get_value(disp_str)
    index = get_value(index_str)

    base + disp + index
  end

  def dump_at_exit
    lines = []
    @mem.data.each_with_index do |n, i|
      line = format("%04d (% 4d) (0x% 4x)", i, n, n)
      if 32 <= n && n <= 126
        line += " (#{ n.chr })"
      end
      lines << line
    end

    File.open("tmp/dump.txt", "wb") { |f|
      f.puts lines.join("\n")
    }
  end

  # --------------------------------

  def fetch_operand(i)
    @mem.code[@pc][i + 1]
  end

  def add_ab
    @reg_a = @reg_a + @reg_b
  end

  def mult_ab
    @reg_a = @reg_a * @reg_b
  end

  def cp
    arg_src  = fetch_operand(0)
    arg_dest = fetch_operand(1)

    src_val =
      case arg_src
      when Integer then arg_src
      when String  then get_value(arg_src)
      else
        raise panic("arg_src", arg_src)
      end

    set_value(arg_dest, src_val)
  end

  # load effective address
  def lea
    dest = fetch_operand(0)
    src  = fetch_operand(1)

    addr =
      case src
      when /^mem:/
        calc_indirect_addr(src)
      else
        raise panic("src", src)
      end

    set_value(dest, addr)
  end

  def add_sp
    set_sp(@sp + fetch_operand(0))
  end

  def sub_sp
    set_sp(@sp - fetch_operand(0))
  end

  def compare
    result = @reg_b - @reg_a
    @zf = (result == 0) ? FLAG_TRUE : FLAG_FALSE
    @sf = (0 <= result) ? FLAG_TRUE : FLAG_FALSE
  end

  def jump
    jump_dest = fetch_operand(0)
    @pc = jump_dest
  end

  def jump_eq
    if @zf == FLAG_TRUE
      jump_dest = fetch_operand(0)
      @pc = jump_dest
    else
      @pc += 1
    end
  end

  def jump_g
    if @zf == FLAG_FALSE && @sf == FLAG_TRUE
      jump_dest = fetch_operand(0)
      @pc = jump_dest
    else
      @pc += 1
    end
  end

  def call
    set_sp(@sp - 1) # スタックポインタを1減らす
    @mem.data[@sp] = @pc + 1 # 戻り先を記憶
    next_addr = fetch_operand(0) # ジャンプ先
    @pc = next_addr
  end

  def ret
    ret_addr = @mem.data[@sp] # 戻り先アドレスを取得
    @pc = ret_addr # 戻る
    set_sp(@sp + 1) # スタックポインタを戻す
  end

  def push
    arg = fetch_operand(0)

    val_to_push = get_value(arg)

    set_sp(@sp - 1)
    @mem.data[@sp] = val_to_push
  end

  def pop
    arg = fetch_operand(0)
    val = @mem.data[@sp]

    set_value(arg, val)
    set_sp(@sp + 1)
  end

  def read
    raise "stdin is not available" if $stdin_.nil?

    arg = fetch_operand(0)

    c = $stdin_.getc
    n = c.nil? ? EOF : c.ord

    set_value(arg, n)
  end

  def write
    arg_val = fetch_operand(0)
    arg_fd  = fetch_operand(1)

    n =
      case arg_val
      when Integer
        arg_val
      when String
        get_value(arg_val)
      else
        raise panic("arg_val", arg_val)
      end
    c = n.chr

    fd =
      case arg_fd
      when Integer
        arg_fd
      when String
        get_value(arg_fd)
      else
        raise panic("arg_fd", arg_fd)
      end

    case fd
    when 1
      $stdout.write c
    when 2
      $stderr.write c
    else
      raise "invalid fd (#{fd})"
    end

    @output += c
    if 80 < @output.size
      @output = @output[1..-1]
    end
  end

  def set_vram
    arg_vram = fetch_operand(0) # dest (vram)
    arg_val  = fetch_operand(1) # src

    src_val = get_value(arg_val)

    case arg_vram
    when Integer
      @mem.vram[arg_vram] = src_val
    when String
      case arg_vram
      when /^mem:/
        vram_addr = @mem.data[calc_indirect_addr(arg_vram)]
        @mem.vram[vram_addr] = src_val
      else
        raise panic("arg_vram", arg_vram)
      end
    else
      raise panic("arg_vram", arg_vram)
    end
  end

  def get_vram
    arg_vram = fetch_operand(0) # src (vram)
    arg_dest = fetch_operand(1) # dest

    vram_addr =
      case arg_vram
      when Integer
        arg_vram
      when String
        get_value(arg_vram)
      else
        raise panic("arg_vram", arg_vram)
      end

    val = @mem.vram[vram_addr]
    set_value(arg_dest, val)
  end

  def _debug
    @debug = true
  end
end

def env_to_bool(key, default = false)
  if ENV.key?(key)
    case ENV[key]
    when "0" then false
    when "1" then true
    else          default
    end
  else
    false
  end
end

def env_to_int(key, default = 1)
  if ENV.key?(key)
    ENV[key].to_i
  else
    default
  end
end

$stdin_ = nil

if $PROGRAM_NAME == __FILE__
  exe_file = ARGV[0]

  stdin_file = ENV.fetch("STDIN", File.join(__dir__, "tmp/stdin"))
  if File.exist?(stdin_file)
    $stdin_ = File.open(stdin_file, "rb")
  end

  data_size = 2_000_000
  mem = Memory.new(data_size)
  vm = Vm.new(
    mem,
    data_size,
    env_to_bool("DEBUG"),
    env_to_bool("VERBOSE"),
    env_to_int("SKIP", 1)
  )
  vm.load_program_file(exe_file)
  exit_status = vm.start

  if ENV["DUMP_FOR_TEST"] == "1"
    vm.dump_for_test
  end

  exit exit_status
end
