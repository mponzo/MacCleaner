cask "maccleaner" do
  version "0.2.4"
  sha256 "70f13aef6b698d97532060cd85407bc6cc84633f188cb3798837470230751371"

  url "https://github.com/mponzo/MacCleaner/releases/download/v#{version}/MacCleaner-#{version}.dmg"
  name "MacCleaner"
  desc "Local-first open-source Mac cleaner with zero telemetry"
  homepage "https://github.com/mponzo/MacCleaner"

  depends_on macos: ">= :sonoma"

  app "MacCleaner.app"

  zap trash: [
    "~/Library/Preferences/com.maccleaner.app.plist",
    "~/Library/Application Support/MacCleaner",
  ]
end
