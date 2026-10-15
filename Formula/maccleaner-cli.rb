class MaccleanerCli < Formula
  desc "MacCleaner terminal workspace — interactive scan and cleanup (TUI)"
  homepage "https://github.com/mponzo/MacCleaner"
  license "MIT"
  version "0.3.0"

  # Stable: prebuilt universal tarball (filled by Scripts/package-cli.sh after a cli-v* release).
  # url "https://github.com/mponzo/MacCleaner/releases/download/cli-v0.3.0/maccleaner-cli-0.3.0.tar.gz"
  # sha256 "REPLACE_WITH_PACKAGE_CLI_SHA256"

  # Until the first cli-v* asset is published:
  #   brew install --HEAD mponzo/maccleaner/maccleaner-cli
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
