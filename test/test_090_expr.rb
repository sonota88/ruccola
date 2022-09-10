require_relative "helper"

class Test090 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_less_than
    src = <<~SRC
      def main()
        if (1 < 2)
          putchar(111); # o
        else
          putchar(46); # .
        end

        if (1 < 1)
          putchar(111); # o
        else
          putchar(46); # .
        end

        if (2 < 1)
          putchar(111); # o
        else
          putchar(46); # .
        end
      end
    SRC

    output = run_vm(src)

    assert_equal("o..", output)
  end

  # --------------------------------

  def test_true
    src = <<~SRC
      def main()
        if (true)
          putchar(65); # A
        else
          putchar(66); # B
        end
      end
    SRC

    output = run_vm(src)

    assert_equal("A", output)
  end

  def test_false
    src = <<~SRC
      def main()
        if (false)
          putchar(65); # A
        else
          putchar(66); # B
        end
      end
    SRC

    output = run_vm(src)

    assert_equal("B", output)
  end

  # --------------------------------
  # function call

  def test_funcall_noargs
    src = <<~SRC
      def f()
      end

      def main()
        f();
      end
    SRC

    expected = <<-ASM
  _cmt call:f
  call f
    ASM

    actual = compile_to_asm(src)

    assert_equal(
      expected,
      extract_asm_main_body(actual)
    )
  end
end
