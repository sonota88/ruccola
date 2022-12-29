require_relative "common"

KEYWORDS = %w[
  def end var return if case when while
  global
  break
  true false
  _cmt
]

def tokenize(src)
  tokens = []

  pos = 0
  lineno = 1

  while pos < src.size
    rest = src[pos .. -1]

    case rest
    when /\A( +)/
      str = $1
      pos += str.size
    when /\A(\n)/
      str = $1
      pos += str.size
      lineno += 1
    when %r{\A(#.*)$}
      str = $1
      pos += str.size
    when /\A"(.*?)"/
      str = $1
      tokens << Token.new(:str, str, lineno)
      pos += str.size + 2
    when /\A(-?[0-9]+)/
      str = $1
      tokens << Token.new(:int, str.to_i, lineno)
      pos += str.size
    when /\A(==|!=|[<(){}\[\]=;+*\/%,&])/
      str = $1
      tokens << Token.new(:sym, str, lineno)
      pos += str.size
    when /\A([A-Za-z_][A-Za-z0-9_]*)/
      str = $1
      if str == "if"
        tokens << Token.new(:kw, "case", lineno)
        tokens << Token.new(:kw, "when", lineno)
      else
        kind = KEYWORDS.include?(str) ? :kw : :ident
        tokens << Token.new(kind, str, lineno)
      end
      pos += str.size
    else
      p_e rest[0...100]
      raise "must not happen (lineno=#{lineno})"
    end
  end

  tokens
end

# --------------------------------

if $PROGRAM_NAME == __FILE__
  in_file = ARGV[0]
  tokens = tokenize(File.read(in_file))

  tokens.each do |token|
    puts token.to_line()
  end
end
