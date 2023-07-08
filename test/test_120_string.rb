require_relative "helper"

class Test120 < Minitest::Test
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

      def GO_STRINGS() return GO_ALLOC_CURSOR() + GS_ALLOC_CURSOR(); end
      def GS_STRINGS() return 10; end

      def main()
        var [12]g;
        var g_ = &g;
        var c_slash = 47;
        var str_;

        init_globals(g_);
        init_strings();

        str_ = "fdsa";

        print_i(str_size(str_));
        putchar(c_slash);

        print_s(str_);
        putchar(c_slash);
      end
    SRC

    output = run_vm(src)

    assert_equal("4/fdsa/", output)
  end

  def test_020
    src = <<~SRC
      #{@std_src}

      def GO_STRINGS() return GO_ALLOC_CURSOR() + GS_ALLOC_CURSOR(); end
      def GS_STRINGS() return 10; end

      def f(s1_, s2_)
        var c_slash = 47;

        print_s(s1_);
        putchar(c_slash);

        print_s(s2_);
        putchar(c_slash);
      end

      def main()
        var [12]g;
        var g_ = &g;

        init_globals(g_);
        init_strings();

        f("ab", "cd");
      end
    SRC

    output = run_vm(src)

    assert_equal("ab/cd/", output)
  end

  # backslash escaping
  def test_030
    main_src = <<~'SRC'
        var [12]g;
        var g_ = &g;

        init_globals(g_);
        init_strings();

        print_s("1\\2\"3\n4");
    SRC

    src = <<~SRC
      #{@std_src}

      def GO_STRINGS() return GO_ALLOC_CURSOR() + GS_ALLOC_CURSOR(); end
      def GS_STRINGS() return 10; end

      def main()
        #{main_src}
      end
    SRC

    output = run_vm(src)

    assert_equal("1" + "\\" + "2" + '"' + "3" + "\n" + "4", output)
  end
end
