class Monclaude < Formula
  desc "Real-time status line for Claude Code"
  homepage "https://github.com/amirhjalali/monclaude"
  url "https://github.com/amirhjalali/monclaude/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "bf03a79d8827e6e1b45a9938d01b6212551d95f8e31a0030a6108ad08df5ee16"
  license "MIT"

  depends_on "jq"

  def install
    bin.install "monclaude.sh" => "monclaude"
  end

  test do
    assert_equal "Claude", shell_output("#{bin}/monclaude")
  end
end
