require_relative "helper"

class Test090 < Minitest::Test

  def setup
    setup_common()
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
  _cmt call~~f
  call f
  add_sp 0
    ASM

    actual = compile_to_asm(src)

    assert_equal(
      expected,
      extract_asm_main_body(actual)
    )
  end
end
