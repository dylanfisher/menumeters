import AppKit
import Meters

/// The settings window, built in code with no nib or storyboard: a tab per meter over a footer
/// that names the config file and says what is wrong with it. It edits the config through the
/// Meters tier; the file stays the source of truth.
@MainActor
public final class SettingsWindowController: NSWindowController {
    private var config: AppConfig
    private let onChange: (AppConfig) -> Void
    private let configFile: URL
    let cpuTab: CPUSettingsViewController
    let problemLabel = NSTextField(wrappingLabelWithString: "")

    /// `onChange` gets the whole config after each change a control makes.
    public init(
        title: String, state: ConfigStore.State, configFile: URL, hasTwoCoreKinds: Bool,
        onChange: @escaping (AppConfig) -> Void
    ) {
        config = state.config
        self.onChange = onChange
        self.configFile = configFile
        var cpuChange: (CPUConfig) -> Void = { _ in }
        cpuTab = CPUSettingsViewController(
            config: state.config.cpu, hasTwoCoreKinds: hasTwoCoreKinds
        ) { cpuChange($0) }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = title
        // The controller owns the window. Left at its default of true for a window made in
        // code, AppKit would also release it on close, and the controller's reference would
        // then point at a freed window.
        window.isReleasedWhenClosed = false
        super.init(window: window)
        cpuChange = { [weak self] cpu in self?.change { $0.cpu = cpu } }
        window.contentView = makeContent()
        window.setContentSize(window.contentView?.fittingSize ?? window.frame.size)
        window.center()
        show(state)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("SettingsWindowController is built in code, not from a nib")
    }

    /// Shows a state of the config file: its config, and what is wrong with it. While the file
    /// has an error the controls are locked, since a change couldn't be saved.
    public func show(_ state: ConfigStore.State) {
        config = state.config
        cpuTab.show(state.config.cpu)
        cpuTab.isEditable = !state.isFileBroken
        problemLabel.isHidden = state.problem == nil
        guard let problem = state.problem else { return }
        problemLabel.stringValue =
            state.isFileBroken
            ? "The config file isn't applied, so MenuMeters runs on its defaults until it's "
                + "fixed: \(problem.reason)."
            : "\(problem.reason)."
    }

    private func change(_ edit: (inout AppConfig) -> Void) {
        edit(&config)
        onChange(config)
    }

    private func makeContent() -> NSView {
        let tabs = NSTabView()
        let cpuItem = NSTabViewItem(viewController: cpuTab)
        cpuItem.label = "CPU"
        tabs.addTabViewItem(cpuItem)

        let path = (configFile.path as NSString).abbreviatingWithTildeInPath
        let fileLabel = NSTextField(labelWithString: "Settings are saved in \(path).")
        fileLabel.textColor = .secondaryLabelColor
        let reveal = NSButton(title: "Show in Finder", target: self, action: #selector(reveal(_:)))
        reveal.controlSize = .small
        let fileRow = NSStackView(views: [fileLabel, reveal])
        problemLabel.textColor = .systemRed
        problemLabel.preferredMaxLayoutWidth = 440

        let stack = NSStackView(views: [tabs, problemLabel, fileRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 20, right: 20)
        tabs.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        stack.widthAnchor.constraint(equalToConstant: 480).isActive = true
        return stack
    }

    @objc private func reveal(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([configFile])
    }
}
