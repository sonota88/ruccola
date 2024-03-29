require_relative "helper"

class Test140 < Minitest::Test
  def setup
    setup_common()

    @std_src = File.read(
      project_path("selfhost/lib/std.rcl")
    )
  end

  # --------------------------------

  def test_010
    src = <<~SRC
      #{@std_src}

      global x;

      def add2()
        var temp = x; # read
        x = temp + 2; # re-assign
      end

      def main()
        x = 1; # assign
        add2();
        print_i(x); # read
      end
    SRC

    output = run_vm(src)

    assert_equal("3", output)
  end
end
