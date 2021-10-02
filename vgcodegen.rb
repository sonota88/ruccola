require "json"

require_relative "common"

$label_id = 0

class Names
  def initialize
    @names = []
  end

  def add(name, size)
    @names << [name, size]
  end

  def include?(target)
    @names.map{ |name, _| name }.include?(target)
  end

  def disp_lvar(target)
    disp = 0
    @names.each { |name, size|
      disp -= size
      break if name == target
    }
    disp
  end

  def disp_fn_arg(target)
    disp = 0
    @names.each { |name, size|
      break if name == target
      disp += size
    }
    disp + 2
  end

  def index(target)
    @names.map{ |name, _| name }.index(target)
  end
end

# --------------------------------

def gen_var(fn_arg_names, lvar_names, stmt)
  puts "  sub_sp 1"

  if stmt.size == 3
    _, dest, expr = stmt
    _gen_set(fn_arg_names, lvar_names, dest, expr)
  end
end

def gen_var_array(fn_arg_names, lvar_names, stmt)
  _, _, size = stmt
  puts "  sub_sp #{size}"
end

def _gen_expr_addr(fn_arg_names, lvar_names, expr)
  _, arg = expr

  if lvar_names.include?(arg)
    disp = lvar_names.disp_lvar(arg)
    puts "  lea reg_a [bp:#{disp}]  # dest src"
  else
    raise not_yet_impl("arg", arg)
  end
end

def _gen_expr_deref(fn_arg_names, lvar_names, expr)
  gen_expr(fn_arg_names, lvar_names, expr[1])

  # reg_a が指すアドレスに入っている値を reg_a に転送
  # （間接参照を辿る操作）
  puts "  cp [reg_a] reg_a"
end

def _gen_expr_add
  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  add_ab"
end

def _gen_expr_mult
  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  mult_ab"
end

def _gen_expr_eq
  $label_id += 1
  label_id = $label_id

  label_end = "end_eq_#{label_id}"
  label_then = "then_#{label_id}"

  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  compare"
  puts "  jump_eq #{label_then}"

  # else
  puts "  cp 0 reg_a"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  cp 1 reg_a"

  puts "label #{label_end}"
end

def _gen_expr_neq
  $label_id += 1
  label_id = $label_id

  label_end = "end_neq_#{label_id}"
  label_then = "then_#{label_id}"

  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  compare"
  puts "  jump_eq #{label_then}"

  # else
  puts "  cp 1 reg_a"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  cp 0 reg_a"

  puts "label #{label_end}"
end

def _gen_expr_lt
  $label_id += 1
  label_id = $label_id

  label_end  = "end_lt_#{label_id}"
  label_then = "then_#{label_id}"

  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  compare"
  puts "  jump_g #{label_then}"

  # else
  puts "  cp 0 reg_a"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  cp 1 reg_a"

  puts "label #{label_end}"
end

def _gen_expr_unary(fn_arg_names, lvar_names, expr)
  operator, *args = expr

  case operator
  when "addr"
    _gen_expr_addr(fn_arg_names, lvar_names, expr)
  when "deref"
    _gen_expr_deref(fn_arg_names, lvar_names, expr)
  else
    raise not_yet_impl("expr", expr)
  end
end

def _gen_expr_binary(fn_arg_names, lvar_names, expr)
  operator, arg_l, arg_r = expr

  gen_expr(fn_arg_names, lvar_names, arg_l)
  puts "  push reg_a"
  gen_expr(fn_arg_names, lvar_names, arg_r)
  puts "  push reg_a"

  case operator
  when "+"  then _gen_expr_add()
  when "*"  then _gen_expr_mult()
  when "==" then _gen_expr_eq()
  when "!=" then _gen_expr_neq()
  when "lt" then _gen_expr_lt()
  else
    raise not_yet_impl("operator", operator)
  end
end

def gen_expr(fn_arg_names, lvar_names, expr)
  case expr
  when Integer
    puts "  cp #{expr} reg_a"

  when String
    push_arg =
      case
      when fn_arg_names.include?(expr)
        disp = fn_arg_names.disp_fn_arg(expr)
        "[bp:#{disp}]"
      when lvar_names.include?(expr)
        disp = lvar_names.disp_lvar(expr)
        "[bp:#{disp}]"
      else
        raise not_yet_impl("expr", expr)
      end

    puts "  cp #{push_arg} reg_a"

  when Array
    if expr[0] == "funcall"
      _gen_funcall(fn_arg_names, lvar_names, expr[1..-1])
      return
    end

    case expr.size
    when 2
      _gen_expr_unary(fn_arg_names, lvar_names, expr)
    when 3
      _gen_expr_binary(fn_arg_names, lvar_names, expr)
    else
      raise not_yet_impl("expr", expr)
    end

  else
    raise not_yet_impl("expr", expr)
  end
end

def _gen_funcall(fn_arg_names, lvar_names, funcall)
  fn_name, *fn_args = funcall

  if fn_name == "_debug"
    puts "  _debug"
    return
  end

  fn_args.reverse.each do |fn_arg|
    gen_expr(fn_arg_names, lvar_names, fn_arg)
    puts "  push reg_a"
  end

  gen_vm_comment("call  #{fn_name}")
  puts "  call #{fn_name}"
  puts "  add_sp #{fn_args.size}"
end

def gen_call(fn_arg_names, lvar_names, stmt)
  _, *funcall = stmt
  _gen_funcall(fn_arg_names, lvar_names, funcall)
end

def _gen_set(fn_arg_names, lvar_names, dest, expr)
  gen_expr(fn_arg_names, lvar_names, expr)

  case dest
  when String

    case
    when lvar_names.include?(dest)
      disp = lvar_names.disp_lvar(dest)
      puts "  cp reg_a [bp:#{disp}]"
    else
      raise not_yet_impl("dest", dest)
    end

  when Array
    if dest[0] == "deref"
      puts "  push reg_a"

      gen_expr(fn_arg_names, lvar_names, dest[1])

      # この時点で
      #   スタック先頭: セットする値（代入の右辺）
      #   reg_a: 転送先アドレス（代入の左辺）
      # という状態になる

      puts "  pop reg_b"
      puts "  cp reg_b [reg_a]"

    else
      raise not_yet_impl("dest", dest)
    end
  else
    raise not_yet_impl("dest", dest)
  end
end

def gen_set(fn_arg_names, lvar_names, stmt)
  _, dest, expr = stmt
  _gen_set(fn_arg_names, lvar_names, dest, expr)
end

def gen_return(fn_arg_names, lvar_names, stmt)
  _, expr = stmt
  gen_expr(fn_arg_names, lvar_names, expr)
end

def gen_while(fn_arg_names, lvar_names, stmt)
  _, cond_expr, body = stmt

  $label_id += 1
  label_id = $label_id

  label_begin = "while_#{label_id}"
  label_end = "end_while_#{label_id}"

  puts ""

  # ループの先頭
  puts "label #{label_begin}"

  # 条件式の評価 ... 結果が reg_a に入る
  gen_expr(fn_arg_names, lvar_names, cond_expr)

  # 比較対象の値をセット
  puts "  cp 0 reg_b"
  puts "  compare"

  # 条件式の結果が偽の場合ループを抜ける
  puts "  jump_eq #{label_end}"

  # ループの本体
  gen_stmts(fn_arg_names, lvar_names, body)

  # ループの先頭に戻る
  puts "  jump #{label_begin}"

  puts "label #{label_end}"
  puts ""
end

def gen_case(fn_arg_names, lvar_names, stmt)
  _, *when_clauses = stmt

  $label_id += 1
  label_id = $label_id

  when_idx = -1

  label_end = "end_case_#{label_id}"
  label_when_head = "when_#{label_id}"
  label_end_when_head = "end_when_#{label_id}"

  puts ""
  puts "  # -->> case_#{label_id}"

  when_clauses.each do |when_clause|
    when_idx += 1
    cond, *rest = when_clause
    cond_head, *cond_rest = cond

    puts "  # when_#{label_id}_#{when_idx}: #{cond.inspect}"

    # 条件式の結果が reg_a に入る
    puts "  # -->> expr"
    gen_expr(fn_arg_names, lvar_names, cond)
    puts "  # <<-- expr"

    # 式の結果と比較するための値を reg_b に入れる
    puts "  cp 0 reg_b"

    puts "  compare"
    puts "  jump_eq #{label_end_when_head}_#{when_idx}" # 偽の場合

    gen_stmts(fn_arg_names, lvar_names, rest)

    puts "  jump #{label_end}"

    # 条件式の結果が偽の場合ここにジャンプ
    puts "label #{label_end_when_head}_#{when_idx}"
  end

  puts "label #{label_end}"
  puts "  # <<-- case_#{label_id}"
  puts ""
end

def gen_vm_comment(comment)
  puts "  _cmt " + comment.gsub(" ", "~")
end

def gen_stmt(fn_arg_names, lvar_names, stmt)
  case stmt[0]
  when "call"
    gen_call(fn_arg_names, lvar_names, stmt)
  when "set"
    gen_set(fn_arg_names, lvar_names, stmt)
  when "return"
    gen_return(fn_arg_names, lvar_names, stmt)
  when "case"
    gen_case(fn_arg_names, lvar_names, stmt)
  when "while"
    gen_while(fn_arg_names, lvar_names, stmt)
  when "_cmt"
    gen_vm_comment(stmt[1])
  else
    raise not_yet_impl("stmt", stmt)
  end
end

def gen_stmts(fn_arg_names, lvar_names, stmts)
  stmts.each do |stmt|
    gen_stmt(fn_arg_names, lvar_names, stmt)
  end
end

def gen_func_def(func_def)
  fn_name = func_def[1]

  fn_arg_names = Names.new
  func_def[2].each { |fn_arg_name| fn_arg_names.add(fn_arg_name, 1) }

  body = func_def[3]

  puts ""
  puts "label #{fn_name}"
  puts "  push bp"
  puts "  cp sp bp"

  puts ""
  puts "  # -->> #{fn_name} body"

  lvar_names = Names.new

  body.each do |stmt|
    case stmt[0]
    when "var"
      lvar_names.add(stmt[1], 1)
      gen_var(fn_arg_names, lvar_names, stmt)
    when "var_array"
      _, lvar_name, size = stmt
      lvar_names.add(lvar_name, size)
      gen_var_array(fn_arg_names, lvar_names, stmt)
    else
      gen_stmt(fn_arg_names, lvar_names, stmt)
    end
  end

  puts "  # <<-- #{fn_name} body"

  puts ""
  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def gen_top_stmts(rest)
  rest.each do |stmt|
    stmt_head, *stmt_rest = stmt

    case stmt_head
    when "func"
      gen_func_def(stmt)
    else
      raise not_yet_impl("stmt_head", stmt_head)
    end
  end
end

def gen_builtin_getchar
  puts "label getchar"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  read reg_a"

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def gen_builtin_write
  puts "label write"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  cp [bp:2] reg_a"
  puts "  write reg_a [bp:3]"

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def gen_builtin_get_sp
  puts "label get_sp"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  cp sp reg_a"

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def gen_builtin_panic
  puts "label _panic"
  "PANIC\n".each_char do |c|
    puts "  write #{c.ord} 2"
  end
  puts "  exit 1"
end

def gen_builtin_set_vram
  puts "label set_vram"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  set_vram [bp:2] [bp:3]" # vram_addr value

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def gen_builtin_get_vram
  puts "label get_vram"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  get_vram [bp:2] reg_a"

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen(tree)
  puts "  call main"
  puts "  exit 0"

  head, *rest = tree
  # assert head == "top_stmts"
  gen_top_stmts(rest)

  puts ""
  puts "#>builtins"
  gen_builtin_write()
  puts ""
  gen_builtin_getchar()
  puts ""
  gen_builtin_get_sp()
  puts ""
  gen_builtin_panic()
  puts ""
  gen_builtin_set_vram()
  puts ""
  gen_builtin_get_vram()
  puts "#<builtins"
end

src = File.read(ARGV[0])

tree = JSON.parse(src)

codegen(tree)
