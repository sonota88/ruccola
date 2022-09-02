require_relative "helper"

class ParserTest < Minitest::Test
  VG_FILE     = project_path("tmp/test.vg.txt")
  TOKENS_FILE = project_path("tmp/test.tokens.txt")
  TREE_FILE   = project_path("tmp/test.vgt.json")

  # --------------------------------

  def test_func_1
    src = <<-EOS
      def f1()
      end
    EOS

    tree_exp = [
      :top_stmts,
      [:func, "f1", [], []]]

    tree_act = parse(src)

    assert_equal(format(tree_exp), format(tree_act))
  end

  def test_func_2
    src = <<-EOS
      def f1(a, b)
      end
    EOS

    tree_exp = [
      :top_stmts,
      [:func, "f1", ["a", "b"], []]]

    tree_act = parse(src)

    assert_equal(format(tree_exp), format(tree_act))
  end

  # --------------------------------

  def test_return_1
    src = <<-EOS
      return;
    EOS

    tree_exp = [
      [:return]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_return_2
    src = <<-EOS
      return 1;
    EOS

    tree_exp = [
      [:return, 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_var_1
    src = <<-EOS
      var a;
    EOS

    tree_exp = [
      [:var, "a"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_1
    src = <<-EOS
      var a = 1;
    EOS

    tree_exp = [
      [:var, "a", 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_2
    src = <<-EOS
      var a = 1 + 2;
    EOS

    tree_exp = [
      [:var, "a", [:+, 1, 2]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_3
    src = <<-EOS
      var b = a;
    EOS

    tree_exp = [
      [:var, "b", "a"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_4
    src = <<-EOS
      var a = ((b * c) + d) + e;
    EOS

    tree_exp = [
      [:var, "a",
       [:+,
          [:+,
             [:*, "b", "c"],
           "d"],
        "e"]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_set_1
    src = <<-EOS
      a = 1;
    EOS

    tree_exp = [
      [:set, "a", 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_set_2
    src = <<-EOS
      a = b;
    EOS

    tree_exp = [
      [:set, "a", "b"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_call_1
    src = <<-EOS
      foo();
    EOS

    tree_exp = [
      [:call, "foo"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_call_2
    src = <<-EOS
      foo(a, 1);
    EOS

    tree_exp = [
      [:call, "foo", "a", 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_call_set_1
    src = <<-EOS
      a = f2();
    EOS

    tree_exp = [
      [:set, "a",
       [:funcall, "f2"]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_call_set_2
    src = <<-EOS
      a = f2(a, 1);
    EOS

    tree_exp = [
      [:set, "a",
       [:funcall, "f2", "a", 1]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_while_1
    src = <<-EOS
      while (a == 1)
      end
    EOS

    tree_exp = [
      [:while, [:"==", "a", 1], []]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_while_2
    src = <<-EOS
      var a;
      while (a == 1)
        a = 2;
      end
    EOS

    tree_exp = [
      [:var, "a"],
      [:while, [:"==", "a", 1], [
         [:set, "a", 2]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_while_3
    src = <<-EOS
      while (a != b)
      end
    EOS

    tree_exp = [
      [:while,
       [:"!=", "a", "b"],
       []]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_case_1
    src = <<-EOS
      var a;
      case
      when (1)
        a = 2;
      end
    EOS

    tree_exp = [
      [:var, "a"],
      [:case,
       [1, [:set, "a", 2]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_case_2
    src = <<-EOS
      var a;
      case
      when (1) a = 3;
      when (2) a = 4;
      end
    EOS

    tree_exp = [
      [:var, "a"],
      [:case,
       [1, [:set, "a", 3]],
       [2, [:set, "a", 4]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_case_3
    src = <<-EOS
      var a;
      case
      when (a == 1)
        a = 2;
      end
    EOS

    tree_exp = [
      [:var, "a"],
      [:case,
       [[:"==", "a", 1], [:set, "a", 2]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_expr_1
    src = <<-EOS
      var a = 1 + 2 + 3;
    EOS

    tree_exp = [
      [:var, "a",
       [:+,
        [:+, 1, 2],
        3]]]

    tree_act = parse_stmts(src)

    assert_equal(
      format(tree_exp),
      format_stmts(tree_act),
      "should be left-associative"
    )
  end

  # --------------------------------

  def test_cmt
    src = <<-EOS
      _cmt("vm comment");
    EOS

    tree_exp = [
      [:_cmt, "vm comment"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def parse(src)
    File.open(VG_FILE, "wb") { |f| f.print src }
    _system %( ruby #{PROJECT_DIR}/rcl_lexer.rb  #{VG_FILE} > #{TOKENS_FILE} )
    _system %( ruby #{PROJECT_DIR}/rcl_parser.rb #{TOKENS_FILE} > #{TREE_FILE} )
    json = File.read(TREE_FILE)
    JSON.parse(json)
  end

  def format(tree)
    JSON.pretty_generate(tree)
  end

  def parse_stmts(src)
    wrapped_src = <<-EOS
      def test()
        #{src}
      end
    EOS

    parse(wrapped_src)
  end

  def format_stmts(tree)
    func = tree[1]
    body = func[3]
    JSON.pretty_generate(body)
  end
end
