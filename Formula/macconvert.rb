class Macconvert < Formula
  desc "Convert files from Finder's right-click menu - 45 native Quick Actions"
  homepage "https://github.com/pehqge/homebrew-macconvert"
  url "https://github.com/pehqge/homebrew-macconvert/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "bd57d2e73f424051fcaf117ce4adbf49272af6ae61fea27521aabe1efda39767"
  license "MIT"

  depends_on :macos

  def install
    libexec.install Dir["*"]
    bin.write_exec_script libexec/"bin/macconvert"
  end

  def caveats
    c = "\e[36m"   # cyan
    g = "\e[32m"   # green
    b = "\e[1m"    # bold
    r = "\e[0m"    # reset
    <<~EOS

      #{c}#{b}                                                   _   #{r}
      #{c}#{b} _ __ ___   __ _  ___ ___ ___  _ ____   _____ _ __| |_ #{r}
      #{c}#{b}| '_ ` _ \\ / _` |/ __/ __/ _ \\| '_ \\ \\ / / _ \\ '__| __|#{r}
      #{c}#{b}| | | | | | (_| | (_| (_| (_) | | | \\ V /  __/ |  | |_ #{r}
      #{c}#{b}|_| |_| |_|\\__,_|\\___\\___\\___/|_| |_|\\_/ \\___|_|   \\__|#{r}

      #{c}╭─────────────────────────────────────────────────────╮#{r}
      #{c}│#{r}                                                     #{c}│#{r}
      #{c}│#{r}   #{b}One step left! Nothing is enabled yet.#{r}            #{c}│#{r}
      #{c}│#{r}                                                     #{c}│#{r}
      #{c}│#{r}   Run:  #{g}#{b}macconvert setup#{r}                            #{c}│#{r}
      #{c}│#{r}                                                     #{c}│#{r}
      #{c}│#{r}   It opens the picker for the 44 Quick Actions,     #{c}│#{r}
      #{c}│#{r}   installs only the dependencies you need, and      #{c}│#{r}
      #{c}│#{r}   walks you through Send to Kindle.                 #{c}│#{r}
      #{c}│#{r}                                                     #{c}│#{r}
      #{c}╰─────────────────────────────────────────────────────╯#{r}

      To remove everything later, use the built-in uninstaller
      rather than plain brew uninstall:
        macconvert uninstall
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/macconvert version")
  end
end
