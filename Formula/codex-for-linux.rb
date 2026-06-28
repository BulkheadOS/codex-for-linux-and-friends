class CodexForLinux < Formula
  desc "Unofficial local Linux compatibility builder for the OpenAI Codex desktop app"
  homepage "https://github.com/BulkheadOS/codex-for-linux-and-friends"
  license "MIT"

  head "https://github.com/BulkheadOS/codex-for-linux-and-friends.git", branch: "main"

  depends_on "node"
  depends_on "p7zip"
  depends_on "python@3.12"
  depends_on "unzip"

  def install
    libexec.install "bin"
    libexec.install "lib"
    libexec.install "src"
    libexec.install "templates"
    libexec.install ".upstream"
    pkgshare.install "docs"
    pkgshare.install "packaging"
    pkgshare.install "scripts"

    bin.write_exec_script libexec/"bin/codex-linux"
  end

  def caveats
    <<~EOS
      This formula installs only the unofficial builder/updater.
      It does not install or redistribute the OpenAI Codex app.

      Build your private runtime with:
        codex-linux install

      Update when upstream changes:
        codex-linux update
    EOS
  end

  test do
    assert_match "Codex for Linux and friends", shell_output("#{bin}/codex-linux --help")
  end
end
