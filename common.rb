require "pp"

class Token
  attr_reader :kind, :value

  # kind:
  #   str:   string
  #   kw:    keyword
  #   int:   integer
  #   sym:   symbol
  #   ident: identifier
  def initialize(kind, value, lineno)
    @kind = kind
    @value = value
    @lineno = lineno
  end

  def to_line
    "#{@lineno}:#{@kind}:#{@value}"
  end

  def self.from_line(line)
    if /^(\d+?):(.+?):(.+)$/ =~ line
      lineno, sym, str = $1, $2, $3
      Token.new(sym.to_sym, str, lineno.to_i)
    else
      nil
    end
  end

  def to_s
    "(Token kind=#{@kind} value=(_#{@value}_) lineno=#{@lineno})"
  end

  def is(kind, str)
    @kind == kind && @value == str
  end
end

def p_e(*args)
  args.each {|arg| $stderr.puts arg.inspect }
end

def pp_e(*args)
  args.each {|arg| $stderr.puts arg.pretty_inspect }
end

def not_yet_impl(*args)
  "Not yet implemented" +
    args
    .map {|arg| " (#{ arg.inspect })" }
    .join("")
end
