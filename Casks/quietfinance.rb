cask "quietfinance" do
  version "3.0.0"
  sha256 "0d02cdfe1875db6e8d37089f92db6fa0c31aa48051c3d14ff687ff54d7943042"

  url "https://github.com/quietapps/QuietFinance/releases/download/v#{version}/QuietFinance-#{version}.zip",
      verified: "github.com/quietapps/QuietFinance/"
  name "Quiet Finance"
  desc "Track your net worth. Offline. No subscriptions. No cloud."
  homepage "https://github.com/quietapps/QuietFinance"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: ">= :tahoe"

  app "Quiet Finance.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Quiet Finance.app"],
                   sudo: false
    system_command "/System/Library/Frameworks/CoreServices.framework/" \
                   "Versions/A/Frameworks/LaunchServices.framework/" \
                   "Versions/A/Support/lsregister",
                   args: ["-f", "#{appdir}/Quiet Finance.app"],
                   sudo: false,
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Containers/app.quiet.QuietFinance",
    "~/Library/Preferences/app.quiet.QuietFinance.plist",
    "~/Library/Caches/app.quiet.QuietFinance",
    "~/Library/HTTPStorages/app.quiet.QuietFinance",
    "~/Library/Saved Application State/app.quiet.QuietFinance.savedState",
  ]

  caveats <<~EOS
    Quiet Finance is distributed unsigned. The post-install hook strips
    Gatekeeper attributes automatically, but if the app refuses to launch:

      1. Open Finder → /Applications
      2. Right-click Quiet Finance.app → Open
      3. Click "Open" in the dialog

    Or run once in Terminal:
      xattr -cr "/Applications/Quiet Finance.app"
  EOS
end
