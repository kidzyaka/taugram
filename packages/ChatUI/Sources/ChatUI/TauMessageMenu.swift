import Foundation
import TGUIKit
import Localization
import TauSettings

func tauMenuTitles(_ item: TauMessageMenuItem) -> [String] {
    switch item {
    case .reply:
        return [strings().messageContextReply1, strings().chatMenuReplyToOption]
    case .quote:
        return [strings().chatMessageContextQuote]
    case .copy:
        return [strings().chatContextCopyText, strings().chatCopySelectedText]
    case .copyLink:
        return [strings().messageContextCopyMessageLink1]
    case .translate:
        return [strings().chatContextTranslate]
    case .summarize:
        return [strings().chatContextSummarize]
    case .edit:
        return [strings().messageContextEdit]
    case .pin:
        return [strings().messageContextPin, strings().messageContextUnpin]
    case .forward:
        return [strings().messageContextForward]
    case .share:
        return [strings().messageContextShare]
    case .select:
        return [strings().messageContextSelect]
    case .saveMedia:
        return [strings().chatContextSaveMedia, strings().chatContextSaveAllPhotos, strings().chatContextSaveSelectedPhotos]
    case .copyMedia:
        return [strings().chatContextCopyMedia]
    case .saveGif:
        return [strings().messageContextSaveGif, strings().messageContextRemoveGif]
    case .report:
        return [strings().messageContextReport]
    case .delete:
        return [strings().messageContextDelete]
    }
}

func tauFilterMessageMenu(enabled: Bool, _ blocks: [[ContextMenuItem]]) -> [[ContextMenuItem]] {
    guard enabled else {
        return blocks
    }
    let hidden = TauSettings.shared.current.hiddenMenuItems.compactMap(TauMessageMenuItem.init(rawValue:))
    guard !hidden.isEmpty else {
        return blocks
    }
    let titles = Set(hidden.flatMap(tauMenuTitles))
    return blocks.map { block in
        block.filter { !titles.contains($0.title) }
    }
}
