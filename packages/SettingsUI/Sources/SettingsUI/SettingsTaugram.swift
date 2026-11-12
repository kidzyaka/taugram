import Cocoa
import TGUIKit
import TelegramContext

public struct SettingsTaugramEntry {
    public let icon: () -> CGImage
    public let makeController: (any AccountContextProtocol) -> ViewController

    public init(icon: @escaping () -> CGImage, makeController: @escaping (any AccountContextProtocol) -> ViewController) {
        self.icon = icon
        self.makeController = makeController
    }
}
