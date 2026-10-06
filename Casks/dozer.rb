cask "dozer" do
  version "5.1.1"
  sha256 "fb8ee92459f558712b7cd9959ced96aec44babd5d83c9cc913aa70e68decd9be"

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
