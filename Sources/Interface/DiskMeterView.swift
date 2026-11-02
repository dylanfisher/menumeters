import AppKit
import Meters

/// The disk meter in the menu bar: one light, gray while the disks are idle, green while they
/// read, red while they write and orange for both. Drawn into the status item's button as a
/// subview, and only when the activity changes.
@MainActor
final class DiskMeterView: NSView {
    private(set) var drawn = DiskActivity.idle

    private static let diameter: CGFloat = 9

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 15, height: NSStatusBar.system.thickness))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("DiskMeterView is built in code, not from a nib")
    }

    // Clicks go to the status item's button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Shows `activity`, redrawing only if it changed. Returns whether it redrew.
    @discardableResult
    func show(_ activity: DiskActivity) -> Bool {
        guard activity != drawn else { return false }
        drawn = activity
        needsDisplay = true
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor =
            switch drawn {
            case .idle: .tertiaryLabelColor
            case .reading: .systemGreen
            case .writing: .systemRed
            case .readingAndWriting: .systemOrange
            }
        color.setFill()
        let side = Self.diameter
        NSBezierPath(
            ovalIn: NSRect(
                x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side,
                height: side)
        ).fill()
    }
}
