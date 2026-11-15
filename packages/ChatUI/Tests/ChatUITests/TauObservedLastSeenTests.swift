import XCTest
import TelegramCore
import TelegramUtils

final class TauObservedLastSeenTests: XCTestCase {
    private let now: Int32 = 1_800_000_000

    override func tearDown() {
        TauCoreSettings.shared.set(TauCoreFlags())
        super.tearDown()
    }

    private func enable(_ enabled: Bool, dangerous: Bool = true) {
        TauCoreSettings.shared.set(TauCoreFlags(dangerousFeaturesAllowed: dangerous, trackHiddenLastSeen: enabled))
    }

    func testOffByDefault() {
        let presence = TelegramUserPresence(status: .recently(isHidden: false), lastActivity: now - 600)
        XCTAssertNil(tauObservedLastSeen(presence, timeDifference: 0, relativeTo: now))
    }

    func testNeedsDangerousFeatures() {
        enable(true, dangerous: false)
        let presence = TelegramUserPresence(status: .recently(isHidden: false), lastActivity: now - 600)
        XCTAssertNil(tauObservedLastSeen(presence, timeDifference: 0, relativeTo: now))
    }

    func testRecentlyUsesObservedActivity() {
        enable(true)
        let presence = TelegramUserPresence(status: .recently(isHidden: false), lastActivity: now - 600)
        XCTAssertEqual(tauObservedLastSeen(presence, timeDifference: 0, relativeTo: now), now - 600)
    }

    func testAppliesTimeDifference() {
        enable(true)
        let presence = TelegramUserPresence(status: .recently(isHidden: false), lastActivity: now - 600)
        XCTAssertEqual(tauObservedLastSeen(presence, timeDifference: 5, relativeTo: now), now - 605)
    }

    func testNoActivityKeepsServerText() {
        enable(true)
        let presence = TelegramUserPresence(status: .recently(isHidden: false), lastActivity: 0)
        XCTAssertNil(tauObservedLastSeen(presence, timeDifference: 0, relativeTo: now))
    }

    func testStaleActivityOutsideBucketIsIgnored() {
        enable(true)
        let fiveDays: Int32 = 5 * 24 * 60 * 60
        XCTAssertNil(tauObservedLastSeen(TelegramUserPresence(status: .recently(isHidden: false), lastActivity: now - fiveDays), timeDifference: 0, relativeTo: now))
        XCTAssertEqual(tauObservedLastSeen(TelegramUserPresence(status: .lastWeek(isHidden: false), lastActivity: now - fiveDays), timeDifference: 0, relativeTo: now), now - fiveDays)
    }

    func testVisibleLastSeenIsNotReplaced() {
        enable(true)
        XCTAssertNil(tauObservedLastSeen(TelegramUserPresence(status: .present(until: now - 3600), lastActivity: now - 60), timeDifference: 0, relativeTo: now))
        XCTAssertNil(tauObservedLastSeen(TelegramUserPresence(status: .none, lastActivity: now - 60), timeDifference: 0, relativeTo: now))
    }

    func testObservedActivityRefreshesLikeLastSeen() {
        enable(true)
        let presence = TelegramUserPresence(status: .recently(isHidden: false), lastActivity: now - 600)
        XCTAssertEqual(userPresenceStringRefreshTimeout(presence, timeDifference: 0, relativeTo: now), 1.0)
        enable(false)
        XCTAssertEqual(userPresenceStringRefreshTimeout(presence, timeDifference: 0, relativeTo: now), .infinity)
    }
}
