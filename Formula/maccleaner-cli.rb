class MaccleanerCli < Formula
  desc "MacCleaner terminal workspace — interactive scan and cleanup (TUI)"
  homepage "https://github.com/mponzo/MacCleaner"
  license "MIT"
  version "0.3.0"

  # Stable: prebuilt tarball (no Xcode/CLT compile — avoids macOS 26 CLT errors).
  url "https://github.com/mponzo/MacCleaner/releases/download/cli-v0.3.0/maccleaner-cli-0.3.0.tar.gz"
  sha256 "5b915d8882c3f64ecdff6529c7118f577fe29d824739e56ef9b9fdc8dfa670ff"

  head "https://github.com/mponzo/MacCleaner.git", branch: "main"

  depends_on macos: :sonoma
  depends_on xcode: ["15.0", :build] if build.head?

  def install
    if build.head?
      cd "OpenCleanMyMac" do
        system "swift", "build", "-c", "release", "--product", "maccleaner"
        bin.install ".build/release/maccleaner"
      end
    else
      bin.install "maccleaner"
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/maccleaner --version")
  end
end
