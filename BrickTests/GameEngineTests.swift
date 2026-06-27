import XCTest

#if canImport(Brick)
@testable import Brick
#else
@testable import BrickGame
#endif

final class GameEngineTests: XCTestCase {
    func testCompletedLineChangesScoreButNotSelectedSpeed() {
        var board = Array(repeating: Array<TetrominoKind?>(repeating: nil, count: TetrisGame.columns), count: TetrisGame.rows)
        for column in 0..<8 { board[TetrisGame.rows - 1][column] = .j }
        var game = TetrisGame(
            testingBoard: board,
            active: FallingPiece(kind: .o, x: 7, y: TetrisGame.rows - 2),
            speed: .normal
        )
        let originalInterval = game.dropInterval

        game.hardDrop()

        XCTAssertEqual(game.score, 100)
        XCTAssertEqual(game.lines, 1)
        XCTAssertEqual(game.speed, .normal)
        XCTAssertEqual(game.dropInterval, originalInterval)
    }

    func testLineClearsAfterLockDelay() {
        var board = Array(repeating: Array<TetrominoKind?>(repeating: nil, count: TetrisGame.columns), count: TetrisGame.rows)
        for column in 0..<8 { board[TetrisGame.rows - 1][column] = .j }
        var game = TetrisGame(
            testingBoard: board,
            active: FallingPiece(kind: .o, x: 7, y: TetrisGame.rows - 3),
            speed: .normal
        )

        game.advance(by: game.dropInterval)
        XCTAssertEqual(game.score, 0)
        XCTAssertNotNil(game.active)

        game.advance(by: TetrisGame.lockDelay - 0.01)
        XCTAssertEqual(game.score, 0)

        game.advance(by: 0.02)

        XCTAssertEqual(game.score, 100)
        XCTAssertEqual(game.lines, 1)
    }

    func testQueueLongBarUpdatesNextPiece() {
        var game = TetrisGame()
        game.start()

        game.queueLongBar()

        XCTAssertEqual(game.next, .i)
    }

    func testSpeedOnlyChangesWhenPlayerSetsIt() {
        var game = TetrisGame()
        game.setSpeed(.fast)

        XCTAssertEqual(game.speed, .fast)
        XCTAssertEqual(game.dropInterval, 0.38)
    }

    func testSnapshotRestoresActiveGame() throws {
        var game = TetrisGame()
        game.start()
        game.setSpeed(.fast)
        game.moveLeft()

        let restored = try XCTUnwrap(TetrisGame(snapshot: game.snapshot))

        XCTAssertEqual(restored.board, game.board)
        XCTAssertEqual(restored.active, game.active)
        XCTAssertEqual(restored.next, game.next)
        XCTAssertEqual(restored.score, game.score)
        XCTAssertEqual(restored.lines, game.lines)
        XCTAssertEqual(restored.state, game.state)
        XCTAssertEqual(restored.speed, .fast)
    }

    func testPausedGameDoesNotMovePiece() {
        var game = TetrisGame()
        game.start()
        let initialPiece = game.active

        game.togglePause()
        game.tick()

        XCTAssertEqual(game.active?.x, initialPiece?.x)
        XCTAssertEqual(game.active?.y, initialPiece?.y)
    }
}
