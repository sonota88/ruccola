require "fileutils"
require "minitest/autorun"

PROJECT_DIR = File.expand_path("..", __dir__)

$LOAD_PATH.unshift PROJECT_DIR

LF = "\n"

def project_path(path)
  File.join(PROJECT_DIR, path)
end

def temp_path(path)
  File.join(PROJECT_DIR, "tmp", path)
end

def _system(cmd)
  out = `#{cmd}`
  status = $?
  unless status.success?
    raise "Abnormal exit status (#{status.inspect})"
  end
  out
end

def _system_v2(cmd)
  out = `#{cmd}`
  status = $?
  [out, status]
end

def setup_common
  Dir.chdir PROJECT_DIR
  FileUtils.mkdir_p File.join(PROJECT_DIR, "tmp")
  file_write(FILE_STDIN, "")
end

def file_write(path, text)
  File.open(path, "wb") { |f| f.write text }
end

def extract_asm_main_body(asm)
  lines = []
  in_body = false
  asm.each_line { |line|
    if line.chomp == "  # <<-- main body"
      in_body = false
    end

    if in_body
      lines << line
    end

    if line.chomp == "  # -->> main body"
      in_body = true
    end
  }
  lines.join("")
end

FILE_STDIN   = temp_path("stdin")
FILE_SRC     = temp_path("test.vg.txt")
FILE_TOKENS  = temp_path("test.tokens.txt")
FILE_TREE    = temp_path("test.vgt.json")
FILE_ASM     = temp_path("test.vga.txt")
FILE_EXE     = temp_path("test.vge.txt")
FILE_ASM_RB  = temp_path("test_rb.vga.txt")
FILE_ASM_RCL = temp_path("test_rcl.vga.txt")
FILE_OUTPUT  = temp_path("output.txt")

SRC_UTILS = <<SRC

def putchar(c)
  write(c, 1);
end
SRC

def compile_to_asm(src)
  infile = FILE_SRC
  file_write(infile, src)
  _system %( ruby #{PROJECT_DIR}/vglexer.rb   #{infile     } > #{FILE_TOKENS} )
  _system %( ruby #{PROJECT_DIR}/vgparser.rb  #{FILE_TOKENS} > #{FILE_TREE  } )
  _system %( ruby #{PROJECT_DIR}/vgcodegen.rb #{FILE_TREE  } )
end

def build(infile, outfile)
  temp_src = temp_path("test_with_utils.rcl")
  file_write(temp_src, File.read(infile) + SRC_UTILS)

  _system %( ruby #{PROJECT_DIR}/vglexer.rb   #{temp_src   } > #{FILE_TOKENS} )
  _system %( ruby #{PROJECT_DIR}/vgparser.rb  #{FILE_TOKENS} > #{FILE_TREE  } )
  _system %( ruby #{PROJECT_DIR}/vgcodegen.rb #{FILE_TREE  } > #{FILE_ASM   } )
  _system %( ruby #{PROJECT_DIR}/vgasm.rb     #{FILE_ASM   } > #{outfile    } )
end

def rclc_rb(infile, outfile, print_asm: false)
  temp_src = project_path("tmp/test_with_utils.rcl")
  file_write(temp_src, File.read(infile) + SRC_UTILS)

  cmd = [
    project_path("rclc"),
    temp_src,
    "> #{outfile}"
  ].join(" ")

  cmd = "PRINT_ASM=1 " + cmd if print_asm

  Dir.chdir(project_path("./")) do
    _system cmd
  end
end

def rclc_rcl(infile, outfile, print_asm: false)
  temp_src = project_path("tmp/test_with_utils.rcl")
  file_write(temp_src, File.read(infile) + SRC_UTILS)

  cmd = [
    project_path("selfhost/rclc"),
    temp_src,
    "> #{outfile}"
  ].join(" ")

  cmd = "PRINT_ASM=1 " + cmd if print_asm

  Dir.chdir(project_path("selfhost/")) do
    _system cmd
  end
end

def run_vm(src, stdin: "")
  file_write(FILE_SRC, src)

  # compile and assemble
  build(FILE_SRC, FILE_EXE)

  file_write(FILE_STDIN, stdin)
  _system(%( ruby #{PROJECT_DIR}/vgvm.rb #{FILE_EXE} ))
end

def diff_asm(src, name)
  diff_cmd = "ruby " + project_path("test/diff.rb")

  $stderr.puts "test #{name}:"

  file = temp_path("match_asm.rcl")
  file_write(file, src)

  rclc_rb( file, FILE_ASM_RB , print_asm: true)
  rclc_rcl(file, FILE_ASM_RCL, print_asm: true)

  output, status = _system_v2( %( #{diff_cmd} asm #{FILE_ASM_RB} #{FILE_ASM_RCL} ) )
  if status.success?
    pass
  else
    puts output
    flunk
  end
end
