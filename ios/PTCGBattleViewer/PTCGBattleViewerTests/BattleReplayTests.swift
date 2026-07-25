import XCTest
@testable import PTCGBattleViewer

final class BattleReplayTests: XCTestCase {
    private let log = """
    {"schemaVersion":"ptcg-battle-log/v1","battleId":"ios-test","initialState":{"turn":1,"currentPlayer":"matsu","players":{"matsu":{"active":null,"bench":[],"deckCount":2,"handCount":1,"discard":[],"prizesRemaining":6},"take":{"active":null,"bench":[],"deckCount":2,"handCount":1,"discard":[],"prizesRemaining":6}},"winner":null},"events":[{"type":"draw","player":"matsu","count":1},{"type":"end-turn","nextPlayer":"take"},{"type":"declare-winner","player":"take"}]}
    """.data(using: .utf8)!

    func testReplaysInitialStateAndEveryEvent() throws {
        let (battle, snapshots) = try BattleReplay.decode(log)
        XCTAssertEqual(battle.battleId, "ios-test")
        XCTAssertEqual(snapshots.count, 4)
        XCTAssertNil(snapshots[0].event)
        XCTAssertEqual(snapshots[1].state.players["matsu"]?.handCount, 2)
        XCTAssertEqual(snapshots[2].state.currentPlayer, "take")
        XCTAssertEqual(snapshots[3].state.winner, "take")
    }

    func testTracksNamedHandCardsAndCardDetails() throws {
        let detailedLog = """
        {
          "schemaVersion":"ptcg-battle-log/v1",
          "battleId":"hand-details",
          "initialState":{
            "turn":1,
            "currentPlayer":"matsu",
            "players":{
              "matsu":{
                "active":null,
                "bench":[],
                "deckCount":2,
                "handCount":1,
                "hand":[{
                  "id":"pikachu-1",
                  "name":"ピカチュウ",
                  "maxHp":70,
                  "damage":0,
                  "energy":[],
                  "cardType":"雷",
                  "rulesText":"たねポケモン",
                  "attacks":[{"name":"でんきショック","cost":["雷"],"damage":"30","text":"コインを1回投げオモテなら、相手をマヒにする。"}]
                }],
                "discard":[],
                "prizesRemaining":6
              },
              "take":{"active":null,"bench":[],"deckCount":2,"handCount":1,"discard":[],"prizesRemaining":6}
            },
            "winner":null
          },
          "events":[
            {
              "type":"draw",
              "player":"matsu",
              "count":1,
              "cards":[{
                "id":"energy-1",
                "name":"基本雷エネルギー",
                "maxHp":0,
                "damage":0,
                "energy":[],
                "cardType":"エネルギー",
                "rulesText":null,
                "attacks":[]
              }]
            },
            {
              "type":"play-active",
              "player":"matsu",
              "card":{
                "id":"pikachu-1",
                "name":"ピカチュウ",
                "maxHp":70,
                "damage":0,
                "energy":[],
                "cardType":"雷",
                "rulesText":"たねポケモン",
                "attacks":[{"name":"でんきショック","cost":["雷"],"damage":"30","text":null}]
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(detailedLog)
        XCTAssertEqual(snapshots[0].state.players["matsu"]?.hand?.first?.name, "ピカチュウ")
        XCTAssertEqual(snapshots[0].state.players["matsu"]?.hand?.first?.attacks?.first?.cost, ["雷"])
        XCTAssertEqual(snapshots[1].state.players["matsu"]?.hand?.map(\.name), ["ピカチュウ", "基本雷エネルギー"])
        XCTAssertEqual(snapshots[2].state.players["matsu"]?.active?.name, "ピカチュウ")
        XCTAssertEqual(snapshots[2].state.players["matsu"]?.hand?.map(\.name), ["基本雷エネルギー"])
        XCTAssertEqual(snapshots[2].state.players["matsu"]?.handCount, 1)
    }

    @MainActor
    func testNavigationIsBoundedAndSupportsArbitraryPosition() {
        let model = BattleViewerModel()
        model.load(log)
        model.previous()
        XCTAssertEqual(model.position, 0)
        model.last()
        XCTAssertEqual(model.position, 3)
        model.next()
        XCTAssertEqual(model.position, 3)
        model.position = 1
        XCTAssertEqual(model.eventDescription, "matsu が山札から 1 枚引いた")
        model.first()
        XCTAssertEqual(model.eventDescription, "対戦開始時の盤面")
    }
}
