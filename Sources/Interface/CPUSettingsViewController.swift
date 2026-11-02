import AppKit
import Meters

/// The CPU tab of the settings window. Each change to a control calls `onChange` with the whole
/// CPU config at once, so the meter follows a slider as it moves.
@MainActor
final class CPUSettingsViewController: NSViewController {
    let enabledBox = NSButton(checkboxWithTitle: "Show the CPU meter", target: nil, action: nil)
    let intervalSlider = NSSlider()
    let intervalLabel = NSTextField(labelWithString: "")
    let percentBox = NSButton(checkboxWithTitle: "Percentage", target: nil, action: nil)
    let graphBox = NSButton(checkboxWithTitle: "Graph", target: nil, action: nil)
    let widthSlider = NSSlider()
    let widthLabel = NSTextField(labelWithString: "")
    let coreKindsBox = NSButton(
        checkboxWithTitle: "Show each kind of core as its own row", target: nil, action: nil)

    private(set) var config: CPUConfig
    private let hasSeveralCoreKinds: Bool
    private let onChange: (CPUConfig) -> Void
    /// False while the config file has an error: the settings can't be saved then.
    var isEditable = true {
        didSet { refresh() }
    }

    init(config: CPUConfig, hasSeveralCoreKinds: Bool, onChange: @escaping (CPUConfig) -> Void) {
        self.config = config
        self.hasSeveralCoreKinds = hasSeveralCoreKinds
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        title = "CPU"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("CPUSettingsViewController is built in code, not from a nib")
    }

    override func loadView() {
        let interval = CPUConfig.intervalSecondsRange
        intervalSlider.minValue = interval.lowerBound
        intervalSlider.maxValue = interval.upperBound
        // One mark every half second.
        intervalSlider.numberOfTickMarks =
            Int((interval.upperBound - interval.lowerBound) / interval.lowerBound) + 1
        intervalSlider.allowsTickMarkValuesOnly = true
        let width = CPUConfig.graphWidthPointsRange
        widthSlider.minValue = Double(width.lowerBound)
        widthSlider.maxValue = Double(width.upperBound)
        if !hasSeveralCoreKinds { coreKindsBox.toolTip = "This Mac has one kind of core." }
        for control in [
            enabledBox, intervalSlider, percentBox, graphBox, widthSlider, coreKindsBox,
        ] as [NSControl] {
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
            [SettingsPage.label("Show:"), percentBox],
            [empty, graphBox],
            [SettingsPage.label("Graph width:"), SettingsPage.sliderRow(widthSlider, widthLabel)],
            [empty, coreKindsBox],
        ])
        refresh()
    }

    /// Shows `config`, as after a hand edit of the file.
    func show(_ config: CPUConfig) {
        self.config = config
        if isViewLoaded { refresh() }
    }

    private func refresh() {
        guard isViewLoaded else { return }
        enabledBox.state = config.isEnabled ? .on : .off
        intervalSlider.doubleValue = config.intervalSeconds
        intervalLabel.stringValue = String(format: "%g s", config.intervalSeconds)
        percentBox.state = config.showsPercent ? .on : .off
        graphBox.state = config.showsGraph ? .on : .off
        widthSlider.integerValue = config.graphWidthPoints
        widthLabel.stringValue = "\(config.graphWidthPoints) px"
        coreKindsBox.state = config.groupsCoreKinds ? .on : .off

        let on = isEditable && config.isEnabled
        enabledBox.isEnabled = isEditable
        intervalSlider.isEnabled = on
        // The meter shows at least one of the two, so the last one on can't be turned off.
        percentBox.isEnabled = on && config.showsGraph
        graphBox.isEnabled = on && config.showsPercent
        widthSlider.isEnabled = on && config.showsGraph
        coreKindsBox.isEnabled = on && hasSeveralCoreKinds
    }

    @objc private func controlChanged(_ sender: Any?) {
        var next = config
        next.isEnabled = enabledBox.state == .on
        next.intervalSeconds = intervalSlider.doubleValue
        next.showsPercent = percentBox.state == .on
        next.showsGraph = graphBox.state == .on
        next.graphWidthPoints = widthSlider.integerValue
        next.groupsCoreKinds = coreKindsBox.state == .on
        // A slider sends its value on every move, most of them the same mark.
        guard next != config else { return }
        config = next
        refresh()
        onChange(next)
    }
}
