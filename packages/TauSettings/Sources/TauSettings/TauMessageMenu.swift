import Foundation

public enum TauMessageMenuItem: String, CaseIterable {
    case reply
    case quote
    case copy
    case copyLink
    case translate
    case summarize
    case edit
    case pin
    case forward
    case share
    case select
    case saveMedia
    case copyMedia
    case saveGif
    case report
    case delete

    //TODOLANG
    public var title: String {
        switch self {
        case .reply:
            return "Reply"
        case .quote:
            return "Quote"
        case .copy:
            return "Copy Text"
        case .copyLink:
            return "Copy Message Link"
        case .translate:
            return "Translate"
        case .summarize:
            return "Summarize"
        case .edit:
            return "Edit"
        case .pin:
            return "Pin and Unpin"
        case .forward:
            return "Forward"
        case .share:
            return "Share"
        case .select:
            return "Select"
        case .saveMedia:
            return "Save Media"
        case .copyMedia:
            return "Copy Media"
        case .saveGif:
            return "Save GIF"
        case .report:
            return "Report"
        case .delete:
            return "Delete"
        }
    }
}

public enum TauSwipeAction: String, CaseIterable {
    case forward
    case edit
    case copy
    case react
    case saveToSaved
    case pin
    case select
    case delete

    //TODOLANG
    public var title: String {
        switch self {
        case .forward:
            return "Forward"
        case .edit:
            return "Edit"
        case .copy:
            return "Copy Text"
        case .react:
            return "Quick Reaction"
        case .saveToSaved:
            return "Save to Saved Messages"
        case .pin:
            return "Pin"
        case .select:
            return "Select"
        case .delete:
            return "Delete"
        }
    }
}
