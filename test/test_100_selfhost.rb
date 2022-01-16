require_relative "helper"

class Test100 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_selfhost
    files = [
      "blank_main.pric",
      "add.pric",
      "addr_deref.pric",
      "less_than.pric",
      "if.pric",
      "while.pric"
    ]

    files.each do |file|
      file_src = project_path("selfhost/test/selfhost/#{file}")
      src = File.read(file_src)
      diff_asm(src, file)
    end
  end

end
