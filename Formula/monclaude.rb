class Monclaude < Formula
  desc "Real-time status line for Claude Code"
  homepage "https://github.com/amirhjalali/monclaude"
  url "https://github.com/amirhjalali/monclaude/archive/refs/tags/v0.3.1.tar.gz"
  sha256 "1b7da8abe3d705af623a8468cd6dbd220f2bca9333281c796f57567bac6dc4c0"
  license "MIT"

  depends_on "jq"

  def install
    bin.install "monclaude.sh" => "monclaude"
  end

  test do
    assert_equal "Claude", shell_output("#{bin}/monclaude")
  end
end
