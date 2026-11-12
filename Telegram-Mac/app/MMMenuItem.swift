import Cocoa
import Localization
import TelegramUtils

class MMMenuItem: NSMenuItem {
    override var title: String {
        get {
            if let identifier = identifier?.rawValue {
                return _NSLocalizedString("\(identifier).title").replacingOccurrences(of: "Telegram", with: appName) // Taugram
            }
            return super.title
        }
        set {
            super.title = newValue
        }
    }
}


class MMMenu : NSMenu {
    override var title: String {
       
        get {
            if let identifier = identifier?.rawValue {
                return _NSLocalizedString("\(identifier).title")
            }
            return super.title
        }
        set {
            super.title = newValue
        }
        
    }
}
