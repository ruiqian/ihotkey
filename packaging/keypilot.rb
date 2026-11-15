# Homebrew cask template. After a notarized release is uploaded to GitHub,
# fill in the repo, version and sha256 (printed by scripts/release.sh), then
# submit to your own tap (brew tap <you>/tap) or to homebrew/homebrew-cask.
cask "keypilot" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/OWNER/KeyPilot/releases/download/v#{version}/KeyPilot-#{version}.dmg"
  name "KeyPilot"
  desc "Free, open-source app shortcuts and window snapping"
  homepage "https://github.com/OWNER/KeyPilot"

  depends_on macos: ">= :monterey"

  app "KeyPilot.app"

  zap trash: [
    "~/Library/Application Support/KeyPilot",
    "~/Library/LaunchAgents/com.keypilot.app.launcher.plist",
  ]
end
