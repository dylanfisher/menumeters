import AppKit
import Meters

/// The network meter in the menu bar: an arrow for each direction, lit while traffic flows,
/// and the rates as text, either or both; sending on top, receiving below. Drawn into the status
/// item's button as a subview, and only when `NetworkDrawState` changes.
@MainActor
final class NetworkMeterView: NSView {
    private let config: NetworkConfig
    private var drawn = NetworkDrawState()
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
    private let textWidth: CGFloat

    private static let inset: CGFloat = 3
    private static let arrowWidth: CGFloat = 7
    private static let gap: CGFloat = 2

    init(config: NetworkConfig) {
        precondition(
            config.showsArrows || config.showsThroughput, "the network meter shows nothing")
        self.config = config
        textWidth = ceil(NSAttributedString(string: "888K", attributes: [.font: font]).size().width)
        var width = Self.inset * 2
        if config.showsArrows { width += Self.arrowWidth }
        if config.showsArrows && config.showsThroughput { width += Self.gap }
        if config.showsThroughput { width += textWidth }
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: NSStatusBar.system.thickness))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("NetworkMeterView is built in code, not from a nib")
    }

    // Clicks go to the status item's button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Shows the rates in bytes per second, redrawing only if an arrow or a number changed.
    func show(sendRate: Double, receiveRate: Double) {
        let next = NetworkDrawState(sendRate: sendRate, receiveRate: receiveRate, config: config)
        guard next != drawn else { return }
        drawn = next
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let half = bounds.height / 2
        var x = Self.inset
        if config.showsArrows {
            drawArrow(up: true, lit: drawn.isSending, x: x, bottom: half)
            drawArrow(up: false, lit: drawn.isReceiving, x: x, bottom: 0)
            x += Self.arrowWidth + Self.gap
        }
        if config.showsThroughput {
            drawRate(drawn.send, right: x + textWidth, bottom: half)
            drawRate(drawn.receive, right: x + textWidth, bottom: 0)
        }
    }

    /// A triangle in the half of the meter starting at `bottom`, pointing up or down.
    private func drawArrow(up: Bool, lit: Bool, x: CGFloat, bottom: CGFloat) {
        let half = bounds.height / 2
        let height: CGFloat = 5
        let base = bottom + (half - height) / 2 + (up ? 0 : height)
        let tip = up ? base + height : base - height
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: x, y: base))
        arrow.line(to: NSPoint(x: x + Self.arrowWidth, y: base))
        arrow.line(to: NSPoint(x: x + Self.arrowWidth / 2, y: tip))
        arrow.close()
        (lit ? NSColor.labelColor : NSColor.tertiaryLabelColor).setFill()
        arrow.fill()
    }

    private func drawRate(_ rate: NetworkDrawState.Rate, right: CGFloat, bottom: CGFloat) {
        let text = NSAttributedString(
            string: NetworkDrawState.text(rate),
            attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        let size = text.size()
        let y = bottom + (bounds.height / 2 - size.height) / 2
        text.draw(at: NSPoint(x: right - size.width, y: y))
    }
}
