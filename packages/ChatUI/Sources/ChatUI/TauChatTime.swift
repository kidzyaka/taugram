import Foundation
import TelegramUtils
import TauSettings

private let tauChatTimeWithSeconds: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    formatter.dateStyle = .none
    formatter.timeZone = NSTimeZone.local
    return formatter
}()

var tauChatTimeFormatter: DateFormatter {
    return TauSettings.shared.current.showMessageSeconds ? tauChatTimeWithSeconds : DateSelectorUtil.chatDateFormatter
}
