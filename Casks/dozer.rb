cask "dozer" do
  version "5.0.0"
  sha256 "0473246001e275add112f803e05ed89ee836a82aec51c95a90cab93cfb9da023"

  url "https://github.com/pawiromitchel/Dozer/releases/download/v#{version}/Dozer.zip"
  name "Dozer"
  desc "Hide menu bar icons"
  homepage "https://github.com/pawiromitchel/Dozer"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Dozer.app"

  # Releases are ad-hoc signed, not notarized: clear quarantine so Gatekeeper doesn't block the first launch.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Dozer.app"],
                          writable_paths: ["Dozer.app"], writable_base: :appdir, must_succeed: false
  end

  uninstall quit: "com.mortennn.Dozer"

  zap trash: "~/Library/Preferences/com.mortennn.Dozer.plist"
end
