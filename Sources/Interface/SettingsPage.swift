import AppKit

/// Builds a tab of the settings window: labels right-aligned in the first column, controls in
/// the second, with the window's margins around them.
@MainActor
enum SettingsPage {
    /// A page of `rows`, each a label and a control; `NSGridCell.emptyContentView` for no label.
    static func make(_ rows: [[NSView]]) -> NSView {
        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 8
        let container = NSView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(
                lessThanOrEqualTo: container.trailingAnchor, constant: -20),
        ])
        return container
    }

    /// A slider 200 points wide with the label that shows its value after it.
    static func sliderRow(_ slider: NSSlider, _ label: NSTextField) -> NSStackView {
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        label.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let stack = NSStackView(views: [slider, label])
        stack.alignment = .firstBaseline
        return stack
    }

    /// A label for a row of the grid.
    static func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }
}
