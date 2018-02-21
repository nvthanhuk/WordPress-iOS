import UIKit

@objc protocol NUXButtonViewControllerDelegate {
    func primaryButtonPressed()
    @objc optional func secondaryButtonPressed()
}

private struct NUXButtonConfig {
    typealias CallBackType = () -> Void

    let title: String
    let isPrimary: Bool
    let callback: CallBackType?
}

class NUXButtonViewController: UIViewController {
    typealias CallBackType = () -> Void

    // MARK: - Properties

    @IBOutlet var shadowView: UIView?
    @IBOutlet var stackView: UIStackView?
    @IBOutlet var bottomButton: NUXButton?
    @IBOutlet var topButton: NUXButton?

    open var delegate: NUXButtonViewControllerDelegate?

    private var topButtonConfig: NUXButtonConfig?
    private var bottomButtonConfig: NUXButtonConfig?

    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        configure(button: bottomButton, withConfig: bottomButtonConfig)
        configure(button: topButton, withConfig: topButtonConfig)
    }

    private func configure(button: NUXButton?, withConfig buttonConfig: NUXButtonConfig?) {
        if let buttonConfig = buttonConfig, let button = button {
            button.setTitle(buttonConfig.title, for: UIControlState())
            button.accessibilityIdentifier = accessibilityIdentifier(for: buttonConfig.title)
            button.isPrimary = buttonConfig.isPrimary
            button.isHidden = false
        } else {
            button?.isHidden = true
        }
    }

    // MARK: public API

    /// Public method to set the button titles.
    ///
    /// - Parameters:
    ///   - primary: Title string for primary button. Required.
    ///   - secondary: Title string for secondary button. Optional.
    func setButtonTitles(primary: String, secondary: String? = nil) {
        bottomButtonConfig = NUXButtonConfig(title: primary, isPrimary: true, callback: nil)
        if let secondaryTitle = secondary {
            topButtonConfig = NUXButtonConfig(title: secondaryTitle, isPrimary: false, callback: nil)
        }
    }

    func setupTopButton(title: String, isPrimary: Bool = false, onTap callback: @escaping CallBackType) {
        topButtonConfig = NUXButtonConfig(title: title, isPrimary: isPrimary, callback: callback)
    }

    func setupButtomButton(title: String, isPrimary: Bool = false, onTap callback: @escaping CallBackType) {
        bottomButtonConfig = NUXButtonConfig(title: title, isPrimary: isPrimary, callback: callback)
    }

    // MARK: - Helpers

    private func accessibilityIdentifier(for string: String?) -> String {
        let buttonId = NSLocalizedString("Button", comment: "Appended accessibility identifier for buttons.")
        return "\(string ?? "") \(buttonId)"
    }

    // MARK: - Button Handling

    @IBAction func primaryButtonPressed(_ sender: Any) {
        guard let callback = bottomButtonConfig?.callback else {
            delegate?.primaryButtonPressed()
            return
        }
        callback()
    }

    @IBAction func secondaryButtonPressed(_ sender: Any) {
        guard let callback = topButtonConfig?.callback else {
            delegate?.secondaryButtonPressed?()
            return
        }
        callback()
    }

}
