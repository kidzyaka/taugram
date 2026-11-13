import Cocoa
import TGUIKit
import SwiftSignalKit
import Localization
import TauSettings

final class TauForceSwipe {
    private weak var item: ChatRowItem?
    private let disposable = MetaDisposable()

    deinit {
        self.disposable.dispose()
    }

    private var action: TauSwipeAction? {
        return TauSettings.shared.current.forceSwipeAction.flatMap(TauSwipeAction.init(rawValue:))
    }

    func begin(_ item: ChatRowItem) {
        self.item = item
    }

    func handlePress(window: Window) -> Bool {
        guard window.inLiveSwiping, let item = self.item, let action = self.action else {
            return false
        }
        self.item = nil
        (item.view as? RevealTableView)?.completeReveal(direction: .none)
        window.abortSwiping()
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        self.perform(action, item: item)
        return true
    }

    private func perform(_ action: TauSwipeAction, item: ChatRowItem) {
        switch action {
        case .forward:
            _ = item.forwardAction()
        case .edit:
            _ = item.editAction()
        case .react:
            _ = item.reactAction()
        case .copy:
            self.invokeMenu(item, titles: tauMenuTitles(.copy))
        case .pin:
            self.invokeMenu(item, titles: tauMenuTitles(.pin))
        case .select:
            self.invokeMenu(item, titles: tauMenuTitles(.select))
        case .delete:
            self.invokeMenu(item, titles: tauMenuTitles(.delete))
        case .saveToSaved:
            self.invokeMenu(item, titles: tauMenuTitles(.forward), submenuTitle: strings().peerSavedMessages)
        }
    }

    private func invokeMenu(_ item: ChatRowItem, titles: [String], submenuTitle: String? = nil) {
        guard let message = item.message else {
            return
        }
        let signal = chatMenuItems(for: message, entry: item.entry, textLayout: nil, chatInteraction: item.chatInteraction, tauUnfiltered: true) |> take(1) |> deliverOnMainQueue
        self.disposable.set(signal.start(next: { items in
            guard let found = items.first(where: { titles.contains($0.title) }) else {
                return
            }
            if let submenuTitle {
                let target = found.submenu?.items.compactMap { $0 as? ContextMenuItem }.first(where: { $0.title == submenuTitle })
                target?.handler?()
            } else {
                found.handler?()
            }
        }))
    }
}
