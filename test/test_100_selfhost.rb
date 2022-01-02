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
      "array.pric",
      "less_than.pric",
      "if.pric",
      "while.pric"
    ]

    diff_cmd = "ruby " + project_path("test/diff.rb")

    files.each do |file|
      $stderr.puts "test #{file}:"

      file_src = project_path("selfhost/test/selfhost/#{file}")

      pricc_rb(  file_src, FILE_ASM_RB  , print_asm: true)
      pricc_pric(file_src, FILE_ASM_PRIC, print_asm: true)

      output, status = _system_v2( %( #{diff_cmd} asm #{FILE_ASM_RB} #{FILE_ASM_PRIC} ) )
      if status.success?
        pass
      else
        puts output
        flunk("failed file: #{file}")
      end
    end
  end

end
