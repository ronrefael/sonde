class Sonde < Formula
  desc "Local-first Claude Code usage, pacing, and session insight (Rust statusline)"
  homepage "https://github.com/ronrefael/sonde"
  version "1.0.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-aarch64-apple-darwin.tar.gz"
      sha256 "ad5ab20364ab60614c601b91618e59d1dbde495efe710061f445bdc3cd93a1c0"
    end
    on_intel do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-x86_64-apple-darwin.tar.gz"
      sha256 "aa6d5c4eab8b830973d82fe5e1c4d2061086225f5cfadb00987baa5325373b13"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "59354b5883abf7ec4d4518e9f8e4240b4116b4c1258e370f70ac96b5193709b5"
    end
    on_intel do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "c41314ab851da5891857848f3ffcce1798e8939fdd5108a948260dc8c0877f10"
    end
  end

  def install
    bin.install "sonde"
  end

  def caveats
    <<~EOS
      To use sonde with Claude Code, add to ~/.claude/settings.json:

        {
          "statusLine": {
            "type": "command",
            "command": "#{bin}/sonde"
          }
        }

      Or run `sonde setup` to do it automatically.

      Default config location: ~/.config/sonde/sonde.toml
    EOS
  end

  test do
    output = shell_output("echo '{}' | #{bin}/sonde 2>/dev/null", 0)
    assert_predicate testpath/"..", :exist?
    refute_match(/error/i, output)
  end
end
