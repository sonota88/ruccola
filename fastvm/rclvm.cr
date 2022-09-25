require "json"

alias RawInsnElem = String | Int32
alias InsnElem = OpCode | String | Int32
alias RawInsn = Array(RawInsnElem)
alias Insn = Array(InsnElem)

enum OpCode
  Exit
  Cp
  Lea
  AddAb
  MultAb
  AddSp
  SubSp
  Compare
  Jump
  JumpEq
  JumpG
  Call
  Ret
  Push
  Pop
  Read
  Write
  SetVram
  GetVram
  VmCmt
  VmDebug

  def self.from(raw_insn_el : RawInsnElem)
    unless raw_insn_el.is_a?(String)
      raise "invalid type (#{raw_insn_el})"
    end

    case raw_insn_el
    when "exit"     then OpCode::Exit
    when "cp"       then OpCode::Cp
    when "lea"      then OpCode::Lea
    when "add_ab"   then OpCode::AddAb
    when "mult_ab"  then OpCode::MultAb
    when "add_sp"   then OpCode::AddSp
    when "sub_sp"   then OpCode::SubSp
    when "compare"  then OpCode::Compare
    when "jump"     then OpCode::Jump
    when "jump_eq"  then OpCode::JumpEq
    when "jump_g"   then OpCode::JumpG
    when "call"     then OpCode::Call
    when "ret"      then OpCode::Ret
    when "push"     then OpCode::Push
    when "pop"      then OpCode::Pop
    when "read"     then OpCode::Read
    when "write"    then OpCode::Write
    when "set_vram" then OpCode::SetVram
    when "get_vram" then OpCode::GetVram
    when "_cmt"     then OpCode::VmCmt
    when "_debug"   then OpCode::VmDebug
    else
      raise "unsupported opcode (#{raw_insn_el})"
    end
  end
end

class Memory
  property code : Array(Insn)
  getter stack : Array(Int32)
  getter vram : Array(Int32)

  STACK_SIZE = 1_000_000

  def initialize
    @code = [] of Insn
    @stack = Array.new(STACK_SIZE, 0)
    @vram = Array.new(50, 0)
  end

  def label?(insn)
    if insn[0] == OpCode::VmCmt
      insn[1].as(String).starts_with?("label:")
    else
      false
    end
  end

  def dump_code(pc)
    s = [] of String
    @code.each_with_index do |insn, i|
      if pc - 3 <= i && i <= pc + 3
        head = label?(insn) ? "" : "  "
        if i == pc
          s << "=> " + "#{i} " + head + insn.inspect
        else
          s << "   " + "#{i} " + head + insn.inspect
        end
      end
    end

    s.join("\n")
  end

  def dump_stack(bp, sp)
    s = [] of String
    @stack.each_with_index do |val, addr|
      next if addr < sp - 2
      next if bp + 2 < addr

      head =
        (addr == sp ? "s" : " ") +
        (addr == bp ? "b" : " ")

      s << "%s %d %d" % [head, addr, val]
    end

    s.join("\n")
  end
end

class Vm
  FLAG_TRUE = 1
  FLAG_FALSE = 0
  EOF = -1

  @reg_a : Int32
  @reg_b : Int32
  @pc : Int32
  @sp : Int32
  @bp : Int32

  @step : Int32

  @stdin : String?
  @stdin_pos = 0

  def initialize(debug : Bool, verbose : Bool, stdin : String?)
    @debug = debug

    @verbose =
      if @debug
        true
      else
        verbose
      end

    @mem = Memory.new

    @reg_a = 0
    @reg_b = 0

    @zf = FLAG_FALSE # zero flag
    @sf = FLAG_FALSE # sign flag

    @pc = 0
    @sp = Memory::STACK_SIZE - 1
    @bp = @sp

    @step = 0

    @stdin = stdin
  end

  def set_sp(addr)
    raise "stack overflow" if addr < 0

    @sp = addr
  end

  def load_program(insns)
    @mem.code = insns
  end

  def load_program_file(path)
    insns = [] of Insn
    File.open(path).each_line do |line|
      raw_insn = [] of RawInsnElem
      raw_insn = RawInsn.from_json(line)

      insn = [] of InsnElem
      raw_insn.each { |it| insn << it }
      insn[0] = OpCode.from(raw_insn[0])

      insns << insn
    end

    load_program(insns)
  end

  def execute : Int32 | Nil
    insn = @mem.code[@pc]

    opcode = insn[0]
    case opcode
    when OpCode::Exit    then return insn[1].as(Int32)
    when OpCode::Cp      then cp()       ; @pc += 1
    when OpCode::Lea     then lea()      ; @pc += 1
    when OpCode::AddAb   then add_ab()   ; @pc += 1
    when OpCode::MultAb  then mult_ab()  ; @pc += 1
    when OpCode::AddSp   then add_sp()   ; @pc += 1
    when OpCode::SubSp   then sub_sp()   ; @pc += 1
    when OpCode::Compare then compare()  ; @pc += 1
    when OpCode::Jump    then jump()
    when OpCode::JumpEq  then jump_eq()
    when OpCode::JumpG   then jump_g()
    when OpCode::Call    then call()
    when OpCode::Ret     then ret()
    when OpCode::Push    then push()     ; @pc += 1
    when OpCode::Pop     then pop()      ; @pc += 1
    when OpCode::Read    then read()     ; @pc += 1
    when OpCode::Write   then write()    ; @pc += 1
    when OpCode::SetVram then set_vram() ; @pc += 1
    when OpCode::GetVram then get_vram() ; @pc += 1
    when OpCode::VmCmt   then              @pc += 1
    when OpCode::VmDebug then _debug()   ; @pc += 1
    else
      raise "unknown opcode #{insn.inspect}"
    end

    nil
  end

  def start
    dump()
    STDIN.gets if @debug

    loop do
      @step += 1

      exit_status = execute()
      if exit_status
        dump()
        return exit_status
      end

      dump()
      STDIN.gets if @debug
    end

    0
  end

  def dump_regs
    "pc(#{@pc}) reg_a(#{@reg_a}) bp(#{@bp}) sp(#{@sp})"
  end

  def dump
    return unless @verbose

    puts "================================"
    puts "step (#{@step})"
    puts dump_regs()
    puts "---- code ----"
    puts @mem.dump_code(@pc)
    puts "---- stack ----"
    puts @mem.dump_stack(@bp, @sp)
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

  def get_value(str : String) : Int32
    case str
    when "reg_a"   then @reg_a
    when "reg_b"   then @reg_b
    when "bp"      then @bp
    when "sp"      then @sp
    when /^-?\d+$/ then str.to_i
    when /^mem:/   then @mem.stack[calc_indirect_addr(str)]
    else
      raise "unsupported (#{str})"
    end
  end

  def calc_indirect_addr(str : String) : Int32
    _, base_str, disp_str, index_str = str.split(":")

    base = get_value(base_str)
    disp = get_value(disp_str)
    index = get_value(index_str)

    base + disp + index
  end

  def cp
    arg_src = @mem.code[@pc][1]
    arg_dest = @mem.code[@pc][2].as(String)

    src_val =
      case arg_src
      when Int32  then arg_src
      when String then get_value(arg_src)
      else
        raise "invalid type (#{arg_src.class})"
      end

    case arg_dest
    when "reg_a" then @reg_a = src_val
    when "reg_b" then @reg_b = src_val
    when "bp"    then @bp    = src_val
    when "sp"    then @sp    = src_val
    when /^mem:/ then @mem.stack[calc_indirect_addr(arg_dest)] = src_val
    else
      raise "unsupported (#{arg_dest.inspect})"
    end
  end

  def lea
    dest = @mem.code[@pc][1].as(String)
    src = @mem.code[@pc][2].as(String)

    addr =
      case src
      when /^mem:/
        calc_indirect_addr(src)
      else
        raise "unsupported (#{src})"
      end

    case dest
    when "reg_a"
      @reg_a = addr
    else
      raise "unsupported (#{dest})"
    end
  end

  def add_ab
    @reg_a = @reg_a + @reg_b
  end

  def mult_ab
    @reg_a = @reg_a * @reg_b
  end

  def add_sp
    set_sp(@sp + @mem.code[@pc][1].as(Int32))
  end

  def sub_sp
    set_sp(@sp - @mem.code[@pc][1].as(Int32))
  end

  def compare
    result = @reg_b - @reg_a
    @zf = (result == 0) ? FLAG_TRUE : FLAG_FALSE
    @sf = (0 <= result) ? FLAG_TRUE : FLAG_FALSE
  end

  def jump
    jump_dest = @mem.code[@pc][1].as(Int32)
    @pc = jump_dest
  end

  def jump_eq
    if @zf == FLAG_TRUE
      jump_dest = @mem.code[@pc][1].as(Int32)
      @pc = jump_dest
    else
      @pc += 1
    end
  end

  def jump_g
    if @zf == FLAG_FALSE && @sf == FLAG_TRUE
      jump_dest = @mem.code[@pc][1].as(Int32)
      @pc = jump_dest
    else
      @pc += 1
    end
  end

  def call
    set_sp(@sp - 1)
    @mem.stack[@sp] = @pc + 1
    next_addr = @mem.code[@pc][1]
    @pc = next_addr.as(Int32)
  end

  def ret
    ret_addr = @mem.stack[@sp]
    @pc = ret_addr
    set_sp(@sp + 1)
  end

  def push
    arg = @mem.code[@pc][1]

    val_to_push =
      case arg
      when Int32  then arg
      when String then get_value(arg)
      else
        raise "invalid type"
      end

    set_sp(@sp - 1)
    @mem.stack[@sp] = val_to_push
  end

  def pop
    arg = @mem.code[@pc][1]
    val = @mem.stack[@sp]

    case arg
    when "reg_a" then @reg_a = val
    when "reg_b" then @reg_b = val
    when "bp"    then @bp = val
    else
      raise "unsupported (#{arg})"
    end

    set_sp(@sp + 1)
  end

  def read
    raise "stdin is not available" if @stdin.nil?

    stdin_str = @stdin.as(String)

    arg = @mem.code[@pc][1]

    n =
      if @stdin_pos < stdin_str.bytesize
        byte : UInt8 = stdin_str.byte_at(@stdin_pos)
        @stdin_pos += 1
        byte.to_i32
      else
        EOF
      end

    case arg
    when "reg_a" then @reg_a = n
    else
      raise "unsupported (#{arg})"
    end
  end

  def write
    arg_val = @mem.code[@pc][1]
    arg_fd  = @mem.code[@pc][2]

    n =
      case arg_val
      when Int32  then arg_val
      when String then get_value(arg_val)
      else
        raise "invalid type (#{arg_val.inspect})"
      end

    fd =
      case arg_fd
      when Int32  then arg_fd
      when String then get_value(arg_fd)
      else
        raise "invalid type (#{arg_fd.inspect})"
      end

    slice = Bytes.new(1)
    slice[0] = n.to_u8

    case fd
    when 1 then STDOUT.write slice
    when 2 then STDERR.write slice
    else
      raise "invalid fd (#{fd.inspect})"
    end
  end

  def set_vram
    arg_vram = @mem.code[@pc][1] # dest
    arg_val = @mem.code[@pc][2]

    src_val =
      case arg_val
      when Int32  then arg_val
      when String then get_value(arg_val)
      else
        raise "invalid type (#{arg_val.inspect})"
      end

    case arg_vram
    when Int32
      @mem.vram[arg_vram] = src_val
    when String
      case arg_vram
      when /^mem:/
        vram_addr = @mem.stack[calc_indirect_addr(arg_vram)]
        @mem.vram[vram_addr] = src_val
      else
        raise "unsupported (#{arg_vram})"
      end
    else
      raise "unsupported (#{arg_vram})"
    end
  end

  def get_vram
    arg_vram = @mem.code[@pc][1] # src
    arg_dest = @mem.code[@pc][2] # dest

    vram_addr =
      case arg_vram
      when Int32
        arg_vram
      when String
        case arg_vram
        when /^mem:/
          @mem.stack[calc_indirect_addr(arg_vram)]
        else
          raise "unsupported (#{arg_vram})"
        end
      else
        raise "unsupported (#{arg_vram})"
      end

    val = @mem.vram[vram_addr]

    case arg_dest
    when "reg_a"
      @reg_a = val
    else
      raise "unsupported (#{arg_dest})"
    end
  end

  def _debug
    @debug = true
  end
end

def env_to_bool(key, default = false)
  if ENV.has_key?(key)
    case ENV[key]
    when "0" then false
    when "1" then true
    else          default
    end
  else
    false
  end
end

exe_file = ARGV[0]

debug = false
verbose = false

stdin_file = ENV.fetch("STDIN", File.join(__DIR__, "tmp/stdin"))
if File.exists?(stdin_file)
  stdin = File.read(stdin_file)
end

vm = Vm.new(debug, verbose, stdin)
vm.load_program_file(exe_file)
exit_status = vm.start()

if env_to_bool("DUMP_FOR_TEST")
  vm.dump_for_test
end

exit exit_status
