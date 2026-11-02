import AppKit
import Meters

/// The Disk tab of the settings window. Each change to a control calls `onChange` with the
/// whole disk config at once.
@MainActor
final class DiskSettingsViewController: NSViewController {
    let enabledBox = NSButton(checkboxWithTitle: "Show the disk meter", target: nil, action: nil)
    let intervalSlider = NSSlider()
    let intervalLabel = NSTextField(labelWithString: "")

    private(set) var config: DiskConfig
    private let onChange: (DiskConfig) -> Void
    /// False while the config file has an error: the settings can't be saved then.
    var isEditable = true {
        didSet { refresh() }
    }

    init(config: DiskConfig, onChange: @escaping (DiskConfig) -> Void) {
        self.config = config
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        title = "Disk"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("DiskSettingsViewController is built in code, not from a nib")
    }

    override func loadView() {
        intervalSlider.minValue = DiskConfig.intervalSecondsRange.lowerBound
        intervalSlider.maxValue = DiskConfig.intervalSecondsRange.upperBound
        for control in [enabledBox, intervalSlider] as [NSControl] {
            control.target = self
            control.action = #selector(controlChanged(_:))
        }
        view = SettingsPage.make([
            [NSGridCell.emptyContentView, enabledBox],
            [
                SettingsPage.label("Update every:"),
                SettingsPage.sliderRow(intervalSlider, intervalLabel),
            ],
        ])
        refresh()
    }

    /// Shows `config`, as after a hand edit of the file.
    func show(_ config: DiskConfig) {
        self.config = config
        if isViewLoaded { refresh() }
    }

    private func refresh() {
        guard isViewLoaded else { return }
        enabledBox.state = config.isEnabled ? .on : .off
        intervalSlider.doubleValue = config.intervalSeconds
        intervalLabel.stringValue = String(format: "%g s", config.intervalSeconds)
        enabledBox.isEnabled = isEditable
        intervalSlider.isEnabled = isEditable && config.isEnabled
    }

    @objc private func controlChanged(_ sender: Any?) {
        var next = config
        next.isEnabled = enabledBox.state == .on
        // Tenths of a second, the shortest interval's step.
        next.intervalSeconds = max(
            (intervalSlider.doubleValue * 10).rounded() / 10,
            DiskConfig.intervalSecondsRange.lowerBound)
        guard next != config else { return }
        config = next
        refresh()
        onChange(next)
    }
}
