/// The app's bundle identifier, and the subsystem every log line goes under. `scripts/bundle`
/// reads this line with sed and fails when `Info.plist` says otherwise, so keep it a plain
/// literal on one line.
public let bundleIdentifier = "com.dylanfisher.MenuMeters"

/// The app's folder name under `~/Library/Application Support`. Kept a plain literal, like
/// `bundleIdentifier`.
public let appDirectoryName = "MenuMeters"
