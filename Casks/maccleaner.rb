cask "maccleaner" do
  version "0.2.7"
  sha256 "96d525322306ed75f6cc98e79ae83b931aa168a9428be69117fc88f300572b25"

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
