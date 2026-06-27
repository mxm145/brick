import BrickGame
import Foundation

enum VerificationError: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw VerificationError.failed(message) }
}

func verifyScoreDoesNotChangeSpeed() throws {
    var board = Array(repeating: Array<TetrominoKind?>(repeating: nil, count: TetrisGame.columns), count: TetrisGame.rows)
    for column in 0..<8 { board[TetrisGame.rows - 1][column] = .j }
    var game = TetrisGame(
        testingBoard: board,
        active: FallingPiece(kind: .o, x: 7, y: TetrisGame.rows - 2),
        speed: .normal
    )
    let initialInterval = game.dropInterval
    game.hardDrop()

    try require(game.score == 100, "Expected a 100-point line clear.")
    try require(game.lines == 1, "Expected one cleared line.")
    try require(game.speed == .normal, "Score changed the selected speed.")
    try require(game.dropInterval == initialInterval, "Score changed the drop interval.")
}

func verifyManualSpeedControl() throws {
    var game = TetrisGame()
    game.setSpeed(.fast)

    try require(game.speed == .fast, "Manual speed selection was not stored.")
    try require(game.dropInterval == 0.38, "Fast speed did not use its fixed interval.")
}

func verifySnapshotRestore() throws {
    var game = TetrisGame()
    game.start()
    game.setSpeed(.fast)
    game.moveLeft()
    guard let restored = TetrisGame(snapshot: game.snapshot) else {
        throw VerificationError.failed("Saved game could not be restored.")
    }

    try require(restored.board == game.board, "Restored board differs from the saved board.")
    try require(restored.active == game.active, "Restored active piece differs from the saved piece.")
    try require(restored.speed == .fast, "Restored speed differs from the saved speed.")
}

func verifyLockDelayAndLineClear() throws {
    var board = Array(repeating: Array<TetrominoKind?>(repeating: nil, count: TetrisGame.columns), count: TetrisGame.rows)
    for column in 0..<8 { board[TetrisGame.rows - 1][column] = .j }
    var game = TetrisGame(
        testingBoard: board,
        active: FallingPiece(kind: .o, x: 7, y: TetrisGame.rows - 3)
    )

    game.advance(by: game.dropInterval)
    try require(game.score == 0, "Piece locked before the lock delay elapsed.")
    game.advance(by: TetrisGame.lockDelay)

    try require(game.score == 100, "A line was not cleared after the lock delay.")
    try require(game.lines == 1, "Expected the completed line to clear after the lock delay.")
}

func verifyLongBarQueue() throws {
    var game = TetrisGame()
    game.start()
    game.queueLongBar()

    try require(game.next == .i, "Queueing a long bar did not update the next piece.")
}

func verifyPauseStopsTicking() throws {
    var game = TetrisGame()
    game.start()
    let startY = game.active?.y
    game.togglePause()
    game.tick()

    try require(game.active?.y == startY, "Paused game advanced a piece.")
}

do {
    try verifyScoreDoesNotChangeSpeed()
    print("PASS: scoring leaves the selected speed unchanged")
    try verifyManualSpeedControl()
    print("PASS: manual speed selection changes only the configured interval")
    try verifySnapshotRestore()
    print("PASS: active game state restores from a snapshot")
    try verifyLockDelayAndLineClear()
    print("PASS: line clears after the fixed lock delay")
    try verifyLongBarQueue()
    print("PASS: the long bar can be queued")
    try verifyPauseStopsTicking()
    print("PASS: pause prevents the timer from moving a piece")
    exit(0)
} catch {
    fputs("FAIL: \(error.localizedDescription)\n", stderr)
    exit(1)
}
