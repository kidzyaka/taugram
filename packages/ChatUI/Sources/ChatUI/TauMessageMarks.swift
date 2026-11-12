import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import InputDataUI
import GeneralRows
import TelegramTheme
import TelegramContext
import TelegramUtils
import Localization
import MessageUtils

func tauDeletedLabel(edited: TextViewLayout?, color: NSColor, font: NSFont) -> TextViewLayout {
    //TODOLANG
    var string = "deleted"
    if let edited {
        string += " · " + edited.attributedString.string
    }
    let layout = TextViewLayout(.initialize(string: string, color: color, font: font), maximumNumberOfLines: 1)
    layout.measure(width: .greatestFiniteMagnitude)
    return layout
}

func tauDeletedFullDate(_ fullDate: String, attribute: TauDeletedMessageAttribute) -> String {
    let date = DateSelectorUtil.chatFullDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(attribute.date)))
    //TODOLANG
    return "\(fullDate)\nDeleted: \(date)"
}

private let _id_version = { (index: Int) -> InputDataIdentifier in
    return InputDataIdentifier("_id_version_\(index)")
}

private func editHistoryEntries(message: Message, history: TauEditHistoryMessageAttribute) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    var versions: [(title: String, text: String, entities: [MessageTextEntity])] = []
    for (i, version) in history.versions.enumerated() {
        let date = DateSelectorUtil.chatFullDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(version.date)))
        //TODOLANG
        let title = i == 0 ? "ORIGINAL · \(date)" : "VERSION \(i + 1) · \(date)"
        versions.append((title.uppercased(), version.text, version.entities))
    }
    var currentDate = message.timestamp
    for attribute in message.attributes {
        if let attribute = attribute as? EditedMessageAttribute {
            currentDate = attribute.date
        }
    }
    let date = DateSelectorUtil.chatFullDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(currentDate)))
    //TODOLANG
    versions.append(("CURRENT · \(date)".uppercased(), message.text, message.textEntities?.entities ?? []))

    for (i, version) in versions.enumerated() {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(version.title), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        let text = version.text.isEmpty ? " " : version.text
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_version(i), equatable: InputDataEquatable(text), comparable: nil, item: { initialSize, stableId in
            let attributed: NSAttributedString = .initialize(string: text, color: theme.colors.text, font: .normal(.text))
            return GeneralTextRowItem(initialSize, stableId: stableId, text: attributed, inset: NSEdgeInsets(left: 20, right: 20, top: 8, bottom: 8), isTextSelectable: true, viewType: .singleItem)
        }))
        index += 1

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }

    return entries
}

func showTauEditHistory(context: any AccountContextProtocol, message: Message) {
    guard let history = message.tauEditHistoryAttribute else {
        return
    }
    let entries = editHistoryEntries(message: message, history: history)
    let signal: Signal<InputDataSignalValue, NoError> = .single(InputDataSignalValue(entries: entries))

    //TODOLANG
    let controller = InputDataController(dataSignal: signal, title: "Edit History", hasDone: false)

    var close: (() -> Void)? = nil
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })

    let modalController = InputDataModalController(controller, size: NSMakeSize(380, 420))
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    showModal(with: modalController, for: context.window)
}
