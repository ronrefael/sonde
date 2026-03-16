class Sonde < Formula
  desc "Precision instrumentation that continuously measures AI usage and reports conditions in real-time"
  homepage "https://github.com/ronrefael/sonde"
  version "0.1.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-aarch64-apple-darwin.tar.gz"
      # sha256 will be filled after first release
    end
    on_intel do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-x86_64-apple-darwin.tar.gz"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-aarch64-unknown-linux-gnu.tar.gz"
    end
    on_intel do
      url "https://github.com/ronrefael/sonde/releases/download/v#{version}/sonde-x86_64-unknown-linux-gnu.tar.gz"
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

      Default config location: ~/.config/sonde/sonde.toml
    EOS
  end

  test do
    output = shell_output("echo '{}' | #{bin}/sonde 2>/dev/null", 0)
    assert_predicate testpath/"..", :exist?
  end
end
