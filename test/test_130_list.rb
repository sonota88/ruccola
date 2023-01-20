require_relative "helper"

class Test130 < Minitest::Test
  def setup
    setup_common()

    @std_src = File.read(
      project_path("selfhost/lib/std.rcl")
    )
    @types_src = File.read(
      project_path("selfhost/lib/types.rcl")
    )
  end

  # --------------------------------

  def test_010
    src = <<~SRC
      #{@std_src}
      #{@types_src}

      def main()
        var [2]g;
        var g_ = &g;
        var c_slash = 47;
        var xs_;

        init_globals(g_);

        xs_ = List_new();

        # 1
        print_i(List_size(xs_));
        putchar(c_slash);

        List_add_int(xs_, 11);
        List_add_int(xs_, -22);

        # 2
        print_i(List_size(xs_));
        putchar(c_slash);

        # 3
        print_i(List_get_as_int(xs_, 0));
        putchar(c_slash);

        # 4
        print_i(List_get_as_int(xs_, 1));
        putchar(c_slash);
      end
    SRC

    output = run_vm(src)

    assert_equal("0/2/11/-22/", output)
  end

  def test_020
    src = <<~SRC
      #{@std_src}
      #{@types_src}

      def main()
        var [2]g;
        var g_ = &g;
        var c_slash = 47;
        var xs_;
        var [3]str;

        init_globals(g_);

        aset(&str, 0, 65); # A
        aset(&str, 1, 66); # B
        aset(&str, 2,  0);

        xs_ = List_new();

        List_add_str(xs_, &str);

        print_s(List_get_as_str(xs_, 0));
        putchar(c_slash);
      end
    SRC

    output = run_vm(src)

    assert_equal("AB/", output)
  end

  def test_030
    src = <<~SRC
      #{@std_src}
      #{@types_src}

      def main()
        var [2]g;
        var g_ = &g;
        var c_slash = 47;
        var xs_;
        var xs_inner_;
        var xs_inner2_;

        init_globals(g_);

        xs_inner_ = List_new();
        List_add_int(xs_inner_, 123);

        xs_ = List_new();
        List_add_list(xs_, xs_inner_);

        # 1
        print_i(List_size(xs_));
        putchar(c_slash);

        xs_inner2_ = List_get_as_list(xs_, 0);

        # 2
        print_i(List_size(xs_inner2_));
        putchar(c_slash);

        # 3
        print_i(List_get_as_int(xs_inner2_, 0));
        putchar(c_slash);
      end
    SRC

    output = run_vm(src)

    assert_equal("1/1/123/", output)
  end

  # add_all
  def test_040
    src = <<~SRC
      #{@std_src}
      #{@types_src}

      def main()
        var [2]g;
        var g_ = &g;
        var c_slash = 47;
        var xs_;
        var xs_inner_;
        var xs_inner2_;

        init_globals(g_);

        xs_inner_ = List_new();
        List_add_int(xs_inner_, 22);
        List_add_int(xs_inner_, 33);

        xs_ = List_new();
        List_add_int(xs_, 11);

        List_add_all(xs_, xs_inner_);

        # 1
        print_i(List_size(xs_));
        putchar(c_slash);

        # 2
        print_i(List_get_as_int(xs_, 0));
        putchar(c_slash);

        # 3
        print_i(List_get_as_int(xs_, 1));
        putchar(c_slash);

        # 4
        print_i(List_get_as_int(xs_, 2));
        putchar(c_slash);
      end
    SRC

    output = run_vm(src)

    assert_equal("3/11/22/33/", output)
  end

  # rest
  def test_050
    src = <<~SRC
      #{@std_src}
      #{@types_src}

      def main()
        var [2]g;
        var g_ = &g;
        var c_slash = 47;
        var xs_;
        var xs2_;

        init_globals(g_);

        xs_ = List_new();
        List_add_int(xs_, 11);
        List_add_int(xs_, 22);
        List_add_int(xs_, 33);
        List_add_int(xs_, 44);

        xs2_ = List_rest(xs_, 2);

        # 1
        print_i(List_size(xs2_));
        putchar(c_slash);

        # 2
        print_i(List_get_as_int(xs2_, 0));
        putchar(c_slash);

        # 3
        print_i(List_get_as_int(xs2_, 1));
        putchar(c_slash);
      end
    SRC

    output = run_vm(src)

    assert_equal("2/33/44/", output)
  end
end
