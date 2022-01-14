require "json"
require "pp"

require_relative "./common"

$tokens = nil
$pos = nil
$strings = []

def read_tokens(src)
  tokens = []

  src.each_line do |line|
    token = Token.from_line(line)
    tokens << token unless token.nil?
  end

  tokens
end

# --------------------------------

class ParseError < StandardError; end

def rest_head
  $tokens[$pos ... $pos + 8]
    .map { |t| format("%s<%s>", t.kind, t.value) }
end

def peek(offset = 0)
  $tokens[$pos + offset]
end

def dump_state(msg = nil)
  pp_e [
    msg,
    $pos,
    rest_head
  ]
end

def assert_value(pos, exp)
  t = peek()

  if t.value != exp
    msg = format(
      "Assertion failed: expected(%s) actual(%s)",
      exp.inspect,
      t.inspect
    )
    raise ParseError, msg
  end
end

def consume(str)
  assert_value($pos, str)
  $pos += 1
end

def end?
  $tokens.size <= $pos
end

# --------------------------------

def _parse_arg
  t = peek()

  unless t.kind == :ident
    raise ParseError, t
  end

  $pos += 1
  t.value
end

def parse_args
  args = []

  if peek().value == ")"
    return args
  end

  args << _parse_arg()

  while peek().value == ","
    consume ","
    args << _parse_arg()
  end

  args
end

# --------------------------------

def parse_exprs
  exprs = []

  if peek().value == ")"
    return exprs
  end

  first_arg = parse_expr()
  if first_arg.nil?
    return exprs
  else
    exprs << first_arg
  end

  while peek().value == ","
    consume ","
    exprs << parse_expr()
  end

  exprs
end

# --------------------------------

def parse_func
  consume "def"

  t = peek()
  $pos += 1
  func_name = t.value

  consume "("
  args = parse_args()
  consume ")"

  stmts = []
  while peek().value != "end"
    stmts <<
      if peek().value == "var"
        parse_var()
      else
        parse_stmt()
      end
  end

  consume "end"

  [:func, func_name, args, stmts]
end

def _parse_var_declare
  t = peek()
  $pos += 1
  var_name = t.value

  consume ";"

  [:var, var_name]
end

def _parse_var_init
  t = peek()
  $pos += 1
  var_name = t.value

  consume "="

  expr = parse_expr()

  consume ";"

  [:var, var_name, expr]
end

def parse_var_array
  consume "["
  t = peek()
  $pos += 1
  size = t.value.to_i
  consume "]"

  var_name = peek().value
  $pos += 1

  consume ";"

  [:var_array, var_name, size]
end

def parse_var
  consume "var"

  if peek().value == "["
    parse_var_array()
  else
    t = peek(1)

    case t.value
    when ";" then _parse_var_declare()
    when "=" then _parse_var_init()
    else
      raise ParseError, t
    end
  end
end

def parse_expr_addr
  consume "&"
  var_name = peek().value
  $pos += 1

  [:addr, var_name]
end

def parse_deref
  consume "*"
  consume "("
  expr = parse_expr()
  consume ")"

  [:deref, expr]
end

def binary_op?(t)
  %(+ * == != <).include?(t.value)
end

def _parse_expr_factor_int
  t = peek()
  $pos += 1
  t.value.to_i
end

def _parse_expr_factor_ident
  if peek(1).value == "("
    fn_name, *args = parse_funcall()
    [:funcall, fn_name, *args]
  else
    t = peek()
    $pos += 1
    t.value
  end
end

def _parse_expr_factor_sym
  case peek().value
  when "("
    consume "("
    expr = parse_expr()
    consume ")"
    expr
  when "&"
    parse_expr_addr()
  when "*"
    parse_deref()
  else
    raise "unexpected token (#{peek()})"
  end
end

def _parse_expr_factor_kw
  t = peek()

  case t.value
  when "true", "false"
    $pos += 1
    t.value
  else
    raise "unexpected token value (#{t})"
  end
end

def _parse_expr_factor_str
  t = peek()

  $pos += 1
  offset = $strings.map { |str| str.bytesize + 1 }.sum
  $strings << t.value

  # g_ + GO_STRINGS() + offset
  [
    :+,
    [
      :+,
      "g_",
      [:funcall, "GO_STRINGS"]
    ],
    offset
  ]
end

def _parse_expr_factor
  t = peek()

  case t.kind
  when :int
    _parse_expr_factor_int()
  when :ident
    _parse_expr_factor_ident()
  when :sym
    _parse_expr_factor_sym()
  when :kw
    _parse_expr_factor_kw()
  when :str
    _parse_expr_factor_str()
  else
    raise ParseError, t
  end
end

def parse_expr
  expr = _parse_expr_factor()

  while binary_op?(peek())
    op = peek().value
    $pos += 1

    factor = _parse_expr_factor()

    expr = [op.to_sym, expr, factor]
  end

  expr
end

def parse_set
  if peek().value == "*"
    var_name = parse_deref()
  else
    t = peek()
    $pos += 1
    var_name = t.value
  end

  consume "="

  expr = parse_expr()

  consume ";"

  [:set, var_name, expr]
end

def parse_funcall
  t = peek()
  $pos += 1
  func_name = t.value

  consume "("
  args = parse_exprs()
  consume ")"

  [func_name, *args]
end

def parse_call
  funcall = parse_funcall()

  consume ";"

  [:call, *funcall]
end

def parse_return
  consume "return"

  t = peek()

  if t.value == ";"
    consume ";"
    [:return]
  else
    expr = parse_expr()
    consume ";"
    [:return, expr]
  end
end

def _parse_when_clause
  t = peek()

  case t.value
  when "when"
    consume "when"
    consume "("
    expr = parse_expr()
    consume ")"
  when "else"
    consume "else"
    expr = 1 # true
  else
    raise not_yet_impl("t", t)
  end

  stmts = parse_stmts()

  [expr, *stmts]
end

def parse_case
  consume "case"

  when_clauses = []

  while peek().value != "end"
    when_clauses << _parse_when_clause()
  end

  consume "end"

  [:case, *when_clauses]
end

def parse_while
  consume "while"

  consume "("
  expr = parse_expr()
  consume ")"

  stmts = parse_stmts()
  consume "end"

  [:while, expr, stmts]
end

def parse_break
  consume "break"
  consume ";"

  [:break]
end

def parse_vm_comment
  consume "_cmt"
  consume "("

  t = peek()
  $pos += 1
  comment = t.value

  consume ")"
  consume ";"

  [:_cmt, comment]
end

def parse_vm_debug
  consume "_debug"
  consume "("
  consume ")"
  consume ";"

  [:call, "_debug"]
end

def parse_vm_panic
  consume "_panic"
  consume "("
  consume ")"
  consume ";"

  [:call, "_panic"]
end

def parse_stmt
  t = peek()

  case t.value
  when "return" then parse_return()
  when "while"  then parse_while()
  when "break"  then parse_break()
  when "case"   then parse_case()
  when "_cmt"   then parse_vm_comment()
  when "_debug" then parse_vm_debug()
  when "_panic" then parse_vm_panic()
  else
    if t.kind == :ident && peek(1).is(:sym, "(")
      parse_call()
    else
      parse_set()
    end
  end
end

def parse_stmts
  stmts = []

  until (
    peek().value == "end" ||
    peek().value == "when" ||
    peek().value == "else"
  )
    stmts << parse_stmt()
  end

  stmts
end

def parse_top_stmt
  t = peek()

  case t.value
  when "def" then parse_func()
  else
    raise ParseError, "Unexpected token (#{t.inspect})"
  end
end

def parse_top_stmts
  stmts = []

  until end?()
    stmts << parse_top_stmt()
  end

  stmts
end

def parse
  top_stmts = parse_top_stmts()
  [:top_stmts, *top_stmts]
end

# --------------------------------

# *(offset + bi) = {byte.to_i};
def make_set_byte_stmt(bi, byte)
  [
    :set,
    [:deref, [:+, "offset_", bi]],
    byte.to_i
  ]
end

# def init_strings(g_)
#   var offset_ = g_ + GO_STRINGS();
#   *(offset_ + 0) = 97;
#   *(offset_ + 1) = 98;
#   *(offset_ + 2) =  0;
#   # ...
# end
def make_init_strings_fn
  stmts = [
    [:var, "offset_", [:+, "g_", [:funcall, "GO_STRINGS"]]]
  ]

  bi = 0
  $strings.each { |str|
    str.each_byte { |byte|
      stmts << make_set_byte_stmt(bi, byte)
      bi += 1
    }
    stmts << make_set_byte_stmt(bi, 0)
    bi += 1
  }

  [:func, "init_strings", ["g_"], stmts]
end

# --------------------------------

in_file = ARGV[0]

$tokens = read_tokens(File.read(in_file))
$pos = 0

begin
  tree = parse()
rescue ParseError => e
  dump_state()
  raise e
end

unless $strings.empty?
  tree << make_init_strings_fn()
end

puts JSON.pretty_generate(tree)
