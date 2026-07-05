cask "sundown" do
  version "1.0.0"
  sha256 "339b84770667a0bdd0444f934e0a7befeeb3f915ed28d73a918b125cc3bd18af"

  url "https://github.com/andreicovaciu/sundown/releases/download/v#{version}/Sundown-#{version}.zip"
  name "Sundown"
  desc "Menu bar app that tells you how much daylight you have left"
  homepage "https://github.com/andreicovaciu/sundown"

  app "Sundown.app"

  zap trash: [
    "~/Library/Preferences/app.sundown.Sundown.plist",
  ]
end
