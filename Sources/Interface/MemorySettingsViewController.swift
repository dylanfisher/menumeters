import AppKit
import Meters

/// The Memory tab of the settings window. Each change to a control calls `onChange` with the
/// whole memory config at once.
@MainActor
final class MemorySettingsViewController: NSViewController {
    let enabledBox = NSButton(checkboxWithTitle: "Show the memory meter", target: nil, action: nil)
    let intervalSlider = NSSlider()
    let intervalLabel = NSTextField(labelWithString: "")
    let displayPopUp = NSPopUpButton()

    private(set) var config: MemoryConfig
    private let onChange: (MemoryConfig) -> Void
    /// False while the config file has an error: the settings can't be saved then.
    var isEditable = true {
        didSet { refresh() }
    }

    private static let displayTitles: [MemoryConfig.Display: String] = [
        .pie: "Pie", .number: "Used and free",
    ]

    init(config: MemoryConfig, onChange: @escaping (MemoryConfig) -> Void) {
        self.config = config
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        title = "Memory"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("MemorySettingsViewController is built in code, not from a nib")
    }

    override func loadView() {
        intervalSlider.minValue = MemoryConfig.intervalSecondsRange.lowerBound
        intervalSlider.maxValue = MemoryConfig.intervalSecondsRange.upperBound
        for display in MemoryConfig.Display.allCases {
            displayPopUp.addItem(withTitle: Self.displayTitles[display] ?? display.rawValue)
        }
        for control in [enabledBox, intervalSlider, displayPopUp] as [NSControl] {
            control.target = self
            control.action = #selector(controlChanged(_:))
        }

        view = SettingsPage.make([
            [NSGridCell.emptyContentView, enabledBox],
            [
                SettingsPage.label("Update every:"),
                SettingsPage.sliderRow(intervalSlider, intervalLabel),
            ],
            [SettingsPage.label("Display:"), displayPopUp],
        ])
        refresh()
    }

    /// Shows `config`, as after a hand edit of the file.
    func show(_ config: MemoryConfig) {
        self.config = config
        if isViewLoaded { refresh() }
    }

    private func refresh() {
        guard isViewLoaded else { return }
        enabledBox.state = config.isEnabled ? .on : .off
        intervalSlider.doubleValue = config.intervalSeconds
        intervalLabel.stringValue = String(format: "%g s", config.intervalSeconds)
        displayPopUp.selectItem(
            at: MemoryConfig.Display.allCases.firstIndex(of: config.display) ?? 0)
        enabledBox.isEnabled = isEditable
        intervalSlider.isEnabled = isEditable && config.isEnabled
        displayPopUp.isEnabled = isEditable && config.isEnabled
    }

    @objc private func controlChanged(_ sender: Any?) {
        var next = config
        next.isEnabled = enabledBox.state == .on
        // Whole seconds: a slider this long would otherwise land between them.
        next.intervalSeconds = intervalSlider.doubleValue.rounded()
        next.display = MemoryConfig.Display.allCases[displayPopUp.indexOfSelectedItem]
        guard next != config else { return }
        config = next
        refresh()
        onChange(next)
    }
}
