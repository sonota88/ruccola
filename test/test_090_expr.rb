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

end
