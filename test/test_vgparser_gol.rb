require_relative "./helper"

class VgparserGolTest < Minitest::Test
  TOKENS_FILE = project_path("tmp/test_vgasm_gol.tokens.txt")
  TREE_FILE = project_path("tmp/test_vgasm_gol.vgt.json")

  def setup
    setup_common()
  end

  def test_vgcg_gol
    system %( ruby #{PROJECT_DIR}/vglexer.rb  #{PROJECT_DIR}/gol.vg.txt > #{TOKENS_FILE} )
    system %( ruby #{PROJECT_DIR}/vgparser.rb #{TOKENS_FILE} > #{TREE_FILE} )

    assert_equal(
      File.read(project_path("test/gol.vgt.json")),
      File.read(TREE_FILE)
    )
  end
end
