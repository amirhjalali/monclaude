class Monclaude < Formula
  desc "Real-time status line for Claude Code"
  homepage "https://github.com/amirhjalali/monclaude"
  url "https://github.com/amirhjalali/monclaude/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "ac9ff6627d434eb0553d2c7a40e41b188e8c9fac4826c1c6a3af4169faf5b1a3"
  license "MIT"

  depends_on "jq"

  def install
    bin.install "monclaude.sh" => "monclaude"
  end

  test do
    assert_equal "Claude", shell_output("#{bin}/monclaude")
  end
end
