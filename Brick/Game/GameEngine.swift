import Foundation

public enum DropSpeed: String, CaseIterable, Identifiable, Equatable {
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"

    public var id: String { rawValue }

    public var interval: TimeInterval {
        switch self {
        case .slow: 1.15
        case .normal: 0.75
        case .fast: 0.38
        }
    }
}

public enum GameState: Equatable {
    case ready, running, paused, over
}

public enum TetrominoKind: CaseIterable, Equatable {
    case i, o, t, s, z, j, l

    public var colorName: String {
        switch self {
        case .i: "cyan"
        case .o: "yellow"
        case .t: "purple"
        case .s: "green"
        case .z: "red"
        case .j: "blue"
        case .l: "orange"
        }
    }

    public func cells(rotation: Int) -> [(Int, Int)] {
        let rotation = rotation % 4
        switch self {
        case .i:
            return rotation % 2 == 0 ? [(0, 1), (1, 1), (2, 1), (3, 1)] : [(2, 0), (2, 1), (2, 2), (2, 3)]
        case .o:
            return [(1, 0), (2, 0), (1, 1), (2, 1)]
        case .t:
            return [[(1, 0), (0, 1), (1, 1), (2, 1)], [(1, 0), (1, 1), (2, 1), (1, 2)], [(0, 1), (1, 1), (2, 1), (1, 2)], [(1, 0), (0, 1), (1, 1), (1, 2)]][rotation]
        case .s:
            return rotation % 2 == 0 ? [(1, 0), (2, 0), (0, 1), (1, 1)] : [(1, 0), (1, 1), (2, 1), (2, 2)]
        case .z:
            return rotation % 2 == 0 ? [(0, 0), (1, 0), (1, 1), (2, 1)] : [(2, 0), (1, 1), (2, 1), (1, 2)]
        case .j:
            return [[(0, 0), (0, 1), (1, 1), (2, 1)], [(1, 0), (2, 0), (1, 1), (1, 2)], [(0, 1), (1, 1), (2, 1), (2, 2)], [(1, 0), (1, 1), (0, 2), (1, 2)]][rotation]
        case .l:
            return [[(2, 0), (0, 1), (1, 1), (2, 1)], [(1, 0), (1, 1), (1, 2), (2, 2)], [(0, 1), (1, 1), (2, 1), (0, 2)], [(0, 0), (1, 0), (1, 1), (1, 2)]][rotation]
        }
    }
}

public struct FallingPiece {
    public let kind: TetrominoKind
    public var x: Int
    public var y: Int
    public var rotation: Int

    public init(kind: TetrominoKind, x: Int, y: Int, rotation: Int = 0) {
        self.kind = kind
        self.x = x
        self.y = y
        self.rotation = rotation
    }
}

public struct TetrisGame {
    public static let columns = 10
    public static let rows = 16
    public static let lockDelay: TimeInterval = 0.35

    public private(set) var board = Array(repeating: Array<TetrominoKind?>(repeating: nil, count: columns), count: rows)
    public private(set) var active: FallingPiece?
    public private(set) var next: TetrominoKind = .t
    public private(set) var score = 0
    public private(set) var lines = 0
    public private(set) var state: GameState = .ready
    public private(set) var speed: DropSpeed = .normal
    private var dropElapsed: TimeInterval = 0
    private var lockElapsed: TimeInterval = 0
    private var isGrounded = false

    public var dropInterval: TimeInterval { speed.interval }

    public var renderedBoard: [[TetrominoKind?]] {
        var rendered = board
        guard let active else { return rendered }
        for (x, y) in cells(for: active) where (0..<Self.columns).contains(x) && (0..<Self.rows).contains(y) {
            rendered[y][x] = active.kind
        }
        return rendered
    }

    public init() {}

    public init(testingBoard: [[TetrominoKind?]], active: FallingPiece, next: TetrominoKind = .t, speed: DropSpeed = .normal) {
        board = testingBoard
        self.active = active
        self.next = next
        self.speed = speed
        state = .running
    }

    public mutating func start() {
        board = Array(repeating: Array(repeating: nil, count: Self.columns), count: Self.rows)
        score = 0
        lines = 0
        state = .running
        resetTiming()
        next = randomKind()
        spawn()
    }

    public mutating func togglePause() {
        guard state == .running || state == .paused else { return }
        state = state == .running ? .paused : .running
    }

    public mutating func setSpeed(_ speed: DropSpeed) {
        self.speed = speed
        dropElapsed = 0
    }

    public mutating func tick() {
        advance(by: dropInterval)
    }

    public mutating func advance(by elapsed: TimeInterval) {
        guard state == .running, elapsed > 0 else { return }
        var remaining = elapsed

        while remaining > 0 {
            if isGrounded {
                let timeToLock = Self.lockDelay - lockElapsed
                if remaining < timeToLock {
                    lockElapsed += remaining
                    return
                }
                lockAndAdvance()
                return
            }

            let timeToDrop = dropInterval - dropElapsed
            if remaining < timeToDrop {
                dropElapsed += remaining
                return
            }
            remaining -= timeToDrop
            dropElapsed = 0
            moveDownOrBeginLockDelay()
        }
    }

    public mutating func moveLeft() {
        if move(dx: -1, dy: 0) { refreshGroundedState() }
    }

    public mutating func moveRight() {
        if move(dx: 1, dy: 0) { refreshGroundedState() }
    }

    public mutating func rotate() {
        guard state == .running, var piece = active else { return }
        piece.rotation = (piece.rotation + 1) % 4
        if canPlace(piece) {
            active = piece
            refreshGroundedState()
            return
        }
        piece.x -= 1
        if canPlace(piece) {
            active = piece
            refreshGroundedState()
            return
        }
        piece.x += 2
        if canPlace(piece) {
            active = piece
            refreshGroundedState()
        }
    }

    public mutating func hardDrop() {
        guard state == .running else { return }
        while move(dx: 0, dy: 1) {}
        lockAndAdvance()
    }

    public mutating func queueLongBar() {
        next = .i
    }

    private mutating func move(dx: Int, dy: Int) -> Bool {
        guard state == .running, var piece = active else { return false }
        piece.x += dx
        piece.y += dy
        guard canPlace(piece) else { return false }
        active = piece
        return true
    }

    private func canPlace(_ piece: FallingPiece) -> Bool {
        cells(for: piece).allSatisfy { x, y in
            (0..<Self.columns).contains(x) && (0..<Self.rows).contains(y) && board[y][x] == nil
        }
    }

    private func canMoveDown(_ piece: FallingPiece) -> Bool {
        var nextPosition = piece
        nextPosition.y += 1
        return canPlace(nextPosition)
    }

    private mutating func moveDownOrBeginLockDelay() {
        if !move(dx: 0, dy: 1) {
            beginLockDelay()
        } else if let active, !canMoveDown(active) {
            beginLockDelay()
        }
    }

    private mutating func refreshGroundedState() {
        guard let active else { return }
        isGrounded = !canMoveDown(active)
        lockElapsed = 0
    }

    private mutating func beginLockDelay() {
        isGrounded = true
        lockElapsed = 0
    }

    private mutating func resetTiming() {
        dropElapsed = 0
        lockElapsed = 0
        isGrounded = false
    }

    private func cells(for piece: FallingPiece) -> [(Int, Int)] {
        piece.kind.cells(rotation: piece.rotation).map { (piece.x + $0.0, piece.y + $0.1) }
    }

    private mutating func lockAndAdvance() {
        guard let active else { return }
        for (x, y) in cells(for: active) where (0..<Self.columns).contains(x) && (0..<Self.rows).contains(y) {
            board[y][x] = active.kind
        }
        self.active = nil
        let remainingRows = board.filter { !$0.allSatisfy { $0 != nil } }
        let clearedCount = Self.rows - remainingRows.count
        board = Array(repeating: Array(repeating: nil, count: Self.columns), count: clearedCount) + remainingRows
        lines += clearedCount
        score += [0, 100, 300, 500, 800][min(clearedCount, 4)]
        resetTiming()
        spawn()
    }

    private mutating func spawn() {
        let piece = FallingPiece(kind: next, x: 3, y: 0)
        next = randomKind()
        guard canPlace(piece) else { state = .over; return }
        active = piece
    }

    private func randomKind() -> TetrominoKind {
        TetrominoKind.allCases.randomElement() ?? .t
    }
}
