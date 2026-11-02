import AppKit
import Meters

/// The Network tab of the settings window. Each change to a control calls `onChange` with the
/// whole network config at once.
@MainActor
final class NetworkSettingsViewController: NSViewController {
    let enabledBox = NSButton(checkboxWithTitle: "Show the network meter", target: nil, action: nil)
    let intervalSlider = NSSlider()
    let intervalLabel = NSTextField(labelWithString: "")
    let arrowsBox = NSButton(checkboxWithTitle: "Arrows", target: nil, action: nil)
    let throughputBox = NSButton(checkboxWithTitle: "Throughput", target: nil, action: nil)

    private(set) var config: NetworkConfig
    private let onChange: (NetworkConfig) -> Void
    /// False while the config file has an error: the settings can't be saved then.
    var isEditable = true {
        didSet { refresh() }
    }

    init(config: NetworkConfig, onChange: @escaping (NetworkConfig) -> Void) {
        self.config = config
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        title = "Network"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("NetworkSettingsViewController is built in code, not from a nib")
    }

    override func loadView() {
        intervalSlider.minValue = NetworkConfig.intervalSecondsRange.lowerBound
        intervalSlider.maxValue = NetworkConfig.intervalSecondsRange.upperBound
        for control in [enabledBox, intervalSlider, arrowsBox, throughputBox] as [NSControl] {
            control.target = self
            control.action = #selector(controlChanged(_:))
        }
        let empty = NSGridCell.emptyContentView
        view = SettingsPage.make([
            [empty, enabledBox],
            [
                SettingsPage.label("Update every:"),
                SettingsPage.sliderRow(intervalSlider, intervalLabel),
            ],
            [SettingsPage.label("Show:"), arrowsBox],
            [empty, throughputBox],
        ])
        refresh()
    }

    /// Shows `config`, as after a hand edit of the file.
    func show(_ config: NetworkConfig) {
        self.config = config
        if isViewLoaded { refresh() }
    }

    private func refresh() {
        guard isViewLoaded else { return }
        enabledBox.state = config.isEnabled ? .on : .off
        intervalSlider.doubleValue = config.intervalSeconds
        intervalLabel.stringValue = String(format: "%g s", config.intervalSeconds)
        arrowsBox.state = config.showsArrows ? .on : .off
        throughputBox.state = config.showsThroughput ? .on : .off
        let on = isEditable && config.isEnabled
        enabledBox.isEnabled = isEditable
        intervalSlider.isEnabled = on
        // The meter shows at least one of the two, so the last one on can't be turned off.
        arrowsBox.isEnabled = on && config.showsThroughput
        throughputBox.isEnabled = on && config.showsArrows
    }

    @objc private func controlChanged(_ sender: Any?) {
        var next = config
        next.isEnabled = enabledBox.state == .on
        // Half seconds, the shortest interval's step.
        next.intervalSeconds = max(
            (intervalSlider.doubleValue * 2).rounded() / 2,
            NetworkConfig.intervalSecondsRange.lowerBound)
        next.showsArrows = arrowsBox.state == .on
        next.showsThroughput = throughputBox.state == .on
        guard next != config else { return }
        config = next
        refresh()
        onChange(next)
    }
}
