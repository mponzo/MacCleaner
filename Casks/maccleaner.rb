cask "maccleaner" do
  version "0.2.4"
  sha256 "dddc38a62e9e2f8f7bf989a37e58356412c5bf167d17b8f60a0f20e6e617f548"

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
