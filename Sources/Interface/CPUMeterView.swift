import AppKit
import Base
import Meters

/// The CPU meter in the menu bar: a percentage, a graph, or both, with one row per core kind
/// shown. Drawn into the status item's button as a subview rather than as a new `NSImage` each
/// tick, and only when `CPUDrawState` changes.
@MainActor
final class CPUMeterView: NSView {
    private let config: CPUConfig
    private var drawn: CPUDrawState
    private var scratch: CPUDrawState
    private let font: NSFont
    /// "0%" through "100%" in `font`, made the first time each is drawn.
    private var percentStrings: [NSAttributedString?] = Array(repeating: nil, count: 101)
    private let percentWidth: CGFloat

    private static let inset: CGFloat = 3
    private static let gap: CGFloat = 3
    private static let rowGap: CGFloat = 1

    init(config: CPUConfig, rowCount: Int) {
        precondition(config.showsPercent || config.showsGraph, "the CPU meter shows nothing")
        self.config = config
        drawn = CPUDrawState(rowCount: rowCount, columnCount: config.graphWidthPoints)
        scratch = drawn
        // Two rows share the height, as yujitach's split percentage does.
        font = NSFont.monospacedDigitSystemFont(ofSize: rowCount == 1 ? 12 : 9, weight: .regular)
        percentWidth = ceil(
            NSAttributedString(string: "100%", attributes: [.font: font]).size().width)
        let height = NSStatusBar.system.thickness
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: height))
        frame.size.width = Self.width(config: config, percentWidth: percentWidth)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("CPUMeterView is built in code, not from a nib")
    }

    private static func width(config: CPUConfig, percentWidth: CGFloat) -> CGFloat {
        var width = inset * 2
        if config.showsPercent { width += percentWidth }
        if config.showsPercent && config.showsGraph { width += gap }
        if config.showsGraph { width += CGFloat(config.graphWidthPoints) }
        return width
    }

    // Clicks go to the status item's button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Shows the newest loads, redrawing only if a percentage or a bar moved by a pixel.
    func show(histories: [RingBuffer<CoreLoad>]) {
        // Before the view is in a window nothing is drawn, so any scale will do.
        let scale = Double(window?.backingScaleFactor ?? 1)
        scratch.update(histories: histories, rowHeightPoints: Double(rowHeight), scale: scale)
        guard scratch != drawn else { return }
        swap(&drawn, &scratch)
        needsDisplay = true
    }

    private var rowHeight: CGFloat {
        let rows = CGFloat(drawn.rowCount)
        return (bounds.height - Self.inset * 2 - Self.rowGap * (rows - 1)) / rows
    }

    override func draw(_ dirtyRect: NSRect) {
        var x = Self.inset
        if config.showsPercent {
            drawPercents(x: x)
            x += percentWidth + Self.gap
        }
        if config.showsGraph { drawGraph(x: x) }
    }

    /// The top of row 0 is the top of the meter; performance cores come first.
    private func rowBottom(_ row: Int) -> CGFloat {
        bounds.height - Self.inset - CGFloat(row + 1) * rowHeight - CGFloat(row) * Self.rowGap
    }

    private func drawPercents(x: CGFloat) {
        for row in 0..<drawn.rowCount {
            let text = percentString(drawn.percents[row])
            let size = text.size()
            let y = rowBottom(row) + (rowHeight - size.height) / 2
            text.draw(at: NSPoint(x: x + percentWidth - size.width, y: y))
        }
    }

    private func percentString(_ percent: Int) -> NSAttributedString {
        if let cached = percentStrings[percent] { return cached }
        let string = NSAttributedString(
            string: "\(percent)%", attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        percentStrings[percent] = string
        return string
    }

    private func drawGraph(x: CGFloat) {
        let pixel = 1 / CGFloat(drawn.scale)
        for row in 0..<drawn.rowCount {
            let bottom = rowBottom(row)
            NSColor.quaternaryLabelColor.setFill()
            NSRect(x: x, y: bottom, width: CGFloat(drawn.columnCount), height: rowHeight).fill()
            for column in 0..<drawn.columnCount {
                let bar = drawn.column(row: row, column: column)
                let left = x + CGFloat(column)
                let system = CGFloat(bar.systemPixels) * pixel
                let total = CGFloat(bar.totalPixels) * pixel
                NSColor.systemRed.setFill()
                NSRect(x: left, y: bottom, width: 1, height: system).fill()
                NSColor.systemBlue.setFill()
                NSRect(x: left, y: bottom + system, width: 1, height: total - system).fill()
            }
        }
    }
}
