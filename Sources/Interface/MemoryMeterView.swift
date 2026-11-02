import AppKit
import Meters

/// The memory meter in the menu bar: a pie of what memory holds, or used and free memory as two
/// lines of numbers. Drawn into the status item's button as a subview, and only when
/// `MemoryDrawState` changes.
@MainActor
final class MemoryMeterView: NSView {
    private let display: MemoryConfig.Display
    private var drawn = MemoryDrawState()
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)

    private static let inset: CGFloat = 3

    /// The pie's wedges clockwise from the top, each with its color; the rest is free.
    private static let wedges: [(KeyPath<MemoryDrawState, Int>, NSColor)] = [
        (\.wiredPercent, .systemRed), (\.activePercent, .systemOrange),
        (\.compressedPercent, .systemPurple), (\.inactivePercent, .systemBlue),
    ]

    init(display: MemoryConfig.Display) {
        self.display = display
        let height = NSStatusBar.system.thickness
        let width: CGFloat
        switch display {
        case .pie:
            width = height
        case .number:
            let widest = NSAttributedString(string: "F 99.9G", attributes: [.font: font])
            width = ceil(widest.size().width) + Self.inset * 2
        }
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("MemoryMeterView is built in code, not from a nib")
    }

    // Clicks go to the status item's button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Shows `stats`, redrawing only if a wedge or a number moved.
    func show(_ stats: MemoryStats) {
        let next = MemoryDrawState(stats, display: display)
        guard next != drawn else { return }
        drawn = next
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        switch display {
        case .pie: drawPie()
        case .number: drawNumbers()
        }
    }

    private func drawPie() {
        let rect = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        let side = min(rect.width, rect.height)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = side / 2
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(
            ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: side, height: side)
        )
        .fill()
        // Angles run counterclockwise from three o'clock; the pie starts at twelve and runs
        // clockwise.
        var angle: CGFloat = 90
        for (percent, color) in Self.wedges {
            let sweep = CGFloat(drawn[keyPath: percent]) * 3.6
            guard sweep > 0 else { continue }
            let wedge = NSBezierPath()
            wedge.move(to: center)
            wedge.appendArc(
                withCenter: center, radius: radius, startAngle: angle, endAngle: angle - sweep,
                clockwise: true)
            wedge.close()
            color.setFill()
            wedge.fill()
            angle -= sweep
        }
    }

    private func drawNumbers() {
        let lines = [
            "U \(MemoryDrawState.gigabytes(tenths: drawn.usedTenths))",
            "F \(MemoryDrawState.gigabytes(tenths: drawn.freeTenths))",
        ]
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.labelColor,
        ]
        let half = bounds.height / 2
        for (index, line) in lines.enumerated() {
            let text = NSAttributedString(string: line, attributes: attributes)
            let size = text.size()
            // The first line goes in the top half.
            let y = half * CGFloat(1 - index) + (half - size.height) / 2
            text.draw(at: NSPoint(x: bounds.width - Self.inset - size.width, y: y))
        }
    }
}
