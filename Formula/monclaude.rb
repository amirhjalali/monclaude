class Monclaude < Formula
  desc "Real-time status line for Claude Code"
  homepage "https://github.com/amirhjalali/monclaude"
  url "https://github.com/amirhjalali/monclaude/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "fdbc634c16d86126095885464b71a978ac7805adc09fe5fa145f7fb40da8a13e"
  license "MIT"

  depends_on "jq"

  def install
    bin.install "monclaude.sh" => "monclaude"
  end

  test do
    assert_equal "Claude", shell_output("#{bin}/monclaude")
  end
end
