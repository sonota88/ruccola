require_relative "helper"

class Test110 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_010
    src = <<~SRC
      def f()
        return 65; # A
        return 66; # B ... should not be executed
      end

      def main()
        putchar(f());
      end
    SRC

    output = run_vm(src)

    assert_equal("A", output)
  end

  # no return value
  def test_020
    src = <<~SRC
      def main()
        putchar(65); # A
        return;
        putchar(66); # B
      end
    SRC

    output = run_vm(src)

    assert_equal("A", output)
  end

  def test_diff_asm
    src = <<~SRC
      def f1()
        return 1;
      end

      def f2()
        return;
      end

      def main()
        f1();
        f2();
      end
    SRC

    diff_asm(src, "return")
  end
end
