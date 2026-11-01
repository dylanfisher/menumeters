import os

/// A logger for the calling module, with the module's name as its category:
/// `private let logger = moduleLogger()` at the top of a file. Categories then match module
/// names without anyone choosing a string, and Console can filter one module at a time.
public func moduleLogger(fileID: String = #fileID) -> Logger {
    Logger(subsystem: bundleIdentifier, category: category(fileID: fileID))
}

/// `#fileID` is `Module/File.swift`.
func category(fileID: String) -> String {
    guard let slash = fileID.firstIndex(of: "/") else {
        preconditionFailure("#fileID \"\(fileID)\" has no module prefix")
    }
    return String(fileID[..<slash])
}
