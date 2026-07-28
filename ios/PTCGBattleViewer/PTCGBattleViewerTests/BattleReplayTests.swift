import XCTest
@testable import PTCGBattleViewer

final class BattleReplayTests: XCTestCase {
    func testViewerHeaderUsesCompactTopEdgeHeight() {
        XCTAssertEqual(CompactLayoutMetrics.headerHeight, 44)
        XCTAssertLessThan(CompactLayoutMetrics.headerHeight, CompactLayoutMetrics.timelineHeight)
    }

    func testCompactLayoutFitsIPhone14ContentHeightWithoutVerticalScrolling() {
        XCTAssertLessThanOrEqual(
            CompactLayoutMetrics.totalContentHeight,
            CompactLayoutMetrics.iPhone14InlineNavigationContentHeight
        )
        XCTAssertEqual(CompactLayoutMetrics.totalContentHeight, 620)
        XCTAssertGreaterThanOrEqual(
            CompactLayoutMetrics.iPhone14InlineNavigationContentHeight - CompactLayoutMetrics.totalContentHeight,
            64
        )
        XCTAssertGreaterThan(
            CompactLayoutMetrics.viewerBoardHeight,
            CompactLayoutMetrics.opponentBoardHeight
        )
    }

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

    func testBoardSeatLayoutIsStableAcrossTurnChanges() {
        let first = BoardSeatLayout(players: ["take", "matsu"])
        let reversed = BoardSeatLayout(players: ["matsu", "take"])

        XCTAssertEqual(first, reversed)
        XCTAssertEqual(first?.viewer, "matsu")
        XCTAssertEqual(first?.opponent, "take")
        XCTAssertNil(BoardSeatLayout(players: ["matsu"]))
    }

    func testDecodesConcretePokemonNamesAndAttacks() throws {
        let data = """
        {"schemaVersion":"ptcg-battle-log/v1","battleId":"card-details","initialState":{"turn":1,"currentPlayer":"あなた","players":{"あなた":{"active":{"id":"pikachu","name":"ピカチュウex","maxHp":200,"damage":30,"energy":["雷"],"attacks":["エレキサークル 60","サンダーボルト 200"]},"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6},"対戦相手":{"active":null,"bench":[],"deckCount":42,"handCount":6,"discard":[],"prizesRemaining":6}},"winner":null},"events":[]}
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(data)
        let card = snapshots[0].state.players["あなた"]?.active
        XCTAssertEqual(card?.name, "ピカチュウex")
        XCTAssertEqual(card?.attacks?.map(\.name), ["エレキサークル 60", "サンダーボルト 200"])
        XCTAssertEqual(card?.retreatCostText, "なし")
    }

    func testDecodesAndDisplaysAttackEnergyCosts() throws {
        let data = """
        {"schemaVersion":"ptcg-battle-log/v1","battleId":"attack-cost","initialState":{"turn":1,"currentPlayer":"あなた","players":{"あなた":{"active":{"id":"pikachu","name":"ピカチュウex","maxHp":200,"damage":0,"energy":[],"attacks":[{"name":"サンダーボルト","damage":"200","cost":["雷","雷","無"]}]},"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6},"対戦相手":{"active":null,"bench":[],"deckCount":42,"handCount":6,"discard":[],"prizesRemaining":6}},"winner":null},"events":[]}
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(data)
        let attack = snapshots[0].state.players["あなた"]?.active?.attacks?.first
        XCTAssertEqual(attack?.displayText, "サンダーボルト 200（必要エネルギー 雷・雷・無）")
    }

    func testPreservesNamedHandCardsDuringReplay() throws {
        let data = """
        {"schemaVersion":"ptcg-battle-log/v1","battleId":"hand-details","initialState":{"turn":1,"currentPlayer":"あなた","players":{"あなた":{"active":null,"bench":[],"deckCount":2,"handCount":1,"hand":[{"id":"pikachu","name":"ピカチュウex","maxHp":200,"damage":0,"energy":[],"cardType":"雷","rulesText":"たねポケモン","attacks":[{"name":"サンダーボルト","damage":"200","cost":["雷","雷","無"]}]}],"discard":[],"prizesRemaining":6},"対戦相手":{"active":null,"bench":[],"deckCount":2,"handCount":1,"discard":[],"prizesRemaining":6}},"winner":null},"events":[{"type":"draw","player":"あなた","count":1,"cards":[{"id":"energy","name":"基本雷エネルギー","maxHp":0,"damage":0,"energy":[]}]},{"type":"play-active","player":"あなた","card":{"id":"pikachu","name":"ピカチュウex","maxHp":200,"damage":0,"energy":[],"attacks":[{"name":"サンダーボルト","damage":"200","cost":["雷","雷","無"]}]}}]}
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(data)
        XCTAssertEqual(snapshots[1].state.players["あなた"]?.hand?.map(\.name), ["ピカチュウex", "基本雷エネルギー"])
        XCTAssertEqual(snapshots[2].state.players["あなた"]?.hand?.map(\.name), ["基本雷エネルギー"])
        XCTAssertEqual(snapshots[2].state.players["あなた"]?.active?.attacks?.first?.cost, ["雷", "雷", "無"])
    }

    func testCardSummaryIncludesCurrentHpAndRetreatCost() throws {
        let data = """
        {"schemaVersion":"ptcg-battle-log/v1","battleId":"card-summary","initialState":{"turn":1,"currentPlayer":"あなた","players":{"あなた":{"active":{"id":"pikachu","name":"ピカチュウex","maxHp":200,"damage":30,"energy":["雷"],"retreatCost":["無","無"],"attacks":[{"name":"サンダーボルト","damage":"200","cost":["雷","雷","無"]}]},"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6},"対戦相手":{"active":null,"bench":[],"deckCount":42,"handCount":6,"discard":[],"prizesRemaining":6}},"winner":null},"events":[]}
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(data)
        let card = try XCTUnwrap(snapshots[0].state.players["あなた"]?.active)
        XCTAssertEqual(card.remainingHp, 170)
        XCTAssertEqual(card.retreatCostText, "無・無")
    }

    func testBothSeatsShareTheSameTurnAtTurnBoundaries() throws {
        let data = """
        {"schemaVersion":"ptcg-battle-log/v1","battleId":"turns","initialState":{"turn":1,"currentPlayer":"あなた","players":{"あなた":{"active":null,"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6},"対戦相手":{"active":null,"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6}},"winner":null},"events":[{"type":"end-turn","nextPlayer":"対戦相手"},{"type":"end-turn","nextPlayer":"あなた"}]}
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(data)
        XCTAssertEqual(snapshots.map(\.state.turn), [1, 2, 3])
        XCTAssertEqual(snapshots.map(\.state.currentPlayer), ["あなた", "対戦相手", "あなた"])
        XCTAssertEqual(snapshots[1].state.players.count, 2)
    }

    func testSupportsFiveNamedBenchPokemonAndMissingNameFallback() throws {
        let data = """
        {"schemaVersion":"ptcg-battle-log/v1","battleId":"bench","initialState":{"turn":1,"currentPlayer":"あなた","players":{"あなた":{"active":null,"bench":[{"id":"b1","name":"ピカチュウ","maxHp":100,"damage":0,"energy":[]},{"id":"b2","name":"ライチュウ","maxHp":120,"damage":0,"energy":[]},{"id":"b3","name":"パモ","maxHp":60,"damage":0,"energy":[]},{"id":"b4","name":"パモット","maxHp":90,"damage":0,"energy":[]},{"id":"b5","name":"","maxHp":100,"damage":0,"energy":[]}],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6},"対戦相手":{"active":null,"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6}},"winner":null},"events":[]}
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(data)
        let bench = try XCTUnwrap(snapshots[0].state.players["あなた"]?.bench)
        XCTAssertEqual(bench.count, 5)
        XCTAssertEqual(bench.map(\.displayName), ["ピカチュウ", "ライチュウ", "パモ", "パモット", "カード名不明"])
    }

    func testTrainerEventsDescribeTheCardEffectAndFallback() throws {
        let data = """
        {"schemaVersion":"ptcg-battle-log/v1","battleId":"trainers","initialState":{"turn":1,"currentPlayer":"あなた","players":{"あなた":{"active":null,"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6},"対戦相手":{"active":null,"bench":[],"deckCount":40,"handCount":5,"discard":[],"prizesRemaining":6}},"winner":null},"events":[{"type":"play-trainer","player":"あなた","cardName":"博士の研究","effect":"手札をすべてトラッシュし、山札を7枚引く"},{"type":"play-trainer","player":"対戦相手","cardName":"","effect":""}]}
        """.data(using: .utf8)!

        let (_, snapshots) = try BattleReplay.decode(data)
        XCTAssertEqual(snapshots[1].event?.description, "あなた が 博士の研究 を使用：手札をすべてトラッシュし、山札を7枚引く")
        XCTAssertEqual(snapshots[2].event?.description, "対戦相手 が トレーナーズ（名前不明） を使用：説明なし")
        XCTAssertEqual(snapshots[2].state.turn, 1)
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
