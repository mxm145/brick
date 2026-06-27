import SwiftUI
import UIKit

enum HorizontalMove {
    case left, right
}

@MainActor
final class GameController: ObservableObject {
    @Published private(set) var game: TetrisGame
    @Published private(set) var leaderboard: [ScoreEntry]
    @Published var timerToken = UUID()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private var continuousMoveTask: Task<Void, Never>?
    private var didRestore = false
    private var lastSavedAt = Date.distantPast

    init() {
        game = GamePersistence.loadGame() ?? TetrisGame()
        leaderboard = GamePersistence.loadLeaderboard()
    }

    func restoreOrStart() {
        guard !didRestore else { return }
        didRestore = true
        if game.state == .ready {
            start()
        } else {
            timerToken = UUID()
        }
    }

    func start() {
        stopContinuousMove()
        game.start()
        timerToken = UUID()
        save(force: true)
    }

    func restart() {
        start()
        feedback()
    }

    func moveLeft() { move(.left, withFeedback: true) }
    func moveRight() { move(.right, withFeedback: true) }

    func rotate() {
        let previousState = game.state
        game.rotate()
        saveAfterGameUpdate(from: previousState)
        feedback()
    }

    func hardDrop() {
        let previousState = game.state
        game.hardDrop()
        saveAfterGameUpdate(from: previousState, force: true)
        feedback()
    }

    func queueLongBar() {
        game.queueLongBar()
        save()
        feedback()
    }

    func togglePause() {
        stopContinuousMove()
        let previousState = game.state
        game.togglePause()
        saveAfterGameUpdate(from: previousState, force: true)
        feedback()
    }

    func setSpeed(_ speed: DropSpeed) {
        let previousState = game.state
        game.setSpeed(speed)
        timerToken = UUID()
        saveAfterGameUpdate(from: previousState, force: true)
        feedback()
    }

    func advance(by elapsed: TimeInterval) {
        let previousState = game.state
        game.advance(by: elapsed)
        saveAfterGameUpdate(from: previousState)
    }

    func saveNow() { save(force: true) }

    func startContinuousMove(_ direction: HorizontalMove) {
        stopContinuousMove()
        move(direction, withFeedback: true)
        continuousMoveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 70_000_000)
                guard !Task.isCancelled else { return }
                self?.move(direction, withFeedback: false)
            }
        }
    }

    func stopContinuousMove() {
        continuousMoveTask?.cancel()
        continuousMoveTask = nil
    }

    private func move(_ direction: HorizontalMove, withFeedback: Bool) {
        let previousState = game.state
        switch direction {
        case .left: game.moveLeft()
        case .right: game.moveRight()
        }
        saveAfterGameUpdate(from: previousState)
        if withFeedback { feedback() }
    }

    private func saveAfterGameUpdate(from previousState: GameState, force: Bool = false) {
        if previousState != .over, game.state == .over {
            leaderboard = GamePersistence.record(game)
            save(force: true)
        } else {
            save(force: force)
        }
    }

    private func save(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastSavedAt) >= 1 else { return }
        GamePersistence.save(game)
        lastSavedAt = .now
    }

    private func feedback() {
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
    }
}

struct ContentView: View {
    @StateObject private var controller = GameController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingLeaderboard = false

    var body: some View {
        GeometryReader { proxy in
            let boardHeight = max(0, min(
                proxy.size.height - 124,
                (proxy.size.width - 32) * CGFloat(TetrisGame.rows) / CGFloat(TetrisGame.columns)
            ))
            let boardWidth = boardHeight * CGFloat(TetrisGame.columns) / CGFloat(TetrisGame.rows)

            VStack(spacing: 8) {
                toolbar
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    BoardView(board: controller.game.renderedBoard)
                        .frame(width: boardWidth, height: boardHeight)
                    Spacer(minLength: 0)
                }
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .task(id: controller.timerToken) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
                guard !Task.isCancelled else { return }
                controller.advance(by: 0.02)
            }
        }
        .onAppear { controller.restoreOrStart() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { controller.saveNow() }
        }
        .onDisappear {
            controller.stopContinuousMove()
            controller.saveNow()
        }
        .sheet(isPresented: $isShowingLeaderboard) {
            LeaderboardView(entries: controller.leaderboard)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 3) {
            compactMetric("Score", value: controller.game.score.formatted())
            compactMetric("Lines", value: controller.game.lines.formatted())
            Divider().frame(height: 28)
            PiecePreview(kind: controller.game.next)
                .frame(width: 28, height: 28)
                .accessibilityLabel("Next piece")
            longBarButton
            Menu {
                ForEach(DropSpeed.allCases) { speed in
                    Button(speed.rawValue) { controller.setSpeed(speed) }
                }
            } label: {
                Text(controller.game.speed.rawValue)
                    .font(.caption2.weight(.semibold))
                    .frame(width: 46, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Drop speed")
            Spacer(minLength: 0)
            toolbarIconButton("list.number", label: "Leaderboard") { isShowingLeaderboard = true }
            toolbarIconButton(
                controller.game.state == .paused ? "play.fill" : "pause.fill",
                label: controller.game.state == .paused ? "Resume game" : "Pause game",
                action: controller.togglePause
            )
            toolbarIconButton("arrow.clockwise", label: "Restart game", action: controller.restart)
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func compactMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit().weight(.semibold))
        }
        .frame(width: title == "Score" ? 68 : 28)
    }

    private var longBarButton: some View {
        Button(action: controller.queueLongBar) {
            VStack(spacing: 2) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 5)
                }
            }
            .frame(width: 44, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set next piece to I bar")
    }

    private func toolbarIconButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(label)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            HorizontalMoveButton(
                icon: "arrow.left",
                label: "Move left",
                tapAction: controller.moveLeft,
                startContinuousMove: { controller.startContinuousMove(.left) },
                stopContinuousMove: controller.stopContinuousMove
            )
            .frame(maxWidth: .infinity)
            HorizontalMoveButton(
                icon: "arrow.right",
                label: "Move right",
                tapAction: controller.moveRight,
                startContinuousMove: { controller.startContinuousMove(.right) },
                stopContinuousMove: controller.stopContinuousMove
            )
            .frame(maxWidth: .infinity)
            controlButton("arrow.clockwise", action: controller.rotate)
                .frame(maxWidth: .infinity)
            controlButton("arrow.down", action: controller.hardDrop)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
    }

    private func controlButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(Color.accentColor)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LeaderboardView: View {
    let entries: [ScoreEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if entries.isEmpty {
                    Text("还没有记录，开始一局吧。")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text("#\(index + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)
                            Text(entry.score.formatted())
                                .font(.title3.monospacedDigit().weight(.semibold))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(entry.lines) lines")
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                        if index < entries.count - 1 { Divider() }
                    }
                    Spacer()
                }
            }
            .padding(20)
            .navigationTitle("排行榜")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct HorizontalMoveButton: View {
    let icon: String
    let label: String
    let tapAction: () -> Void
    let startContinuousMove: () -> Void
    let stopContinuousMove: () -> Void

    @State private var holdTask: Task<Void, Never>?
    @State private var isPressed = false
    @State private var isRepeating = false

    var body: some View {
        Image(systemName: icon)
            .font(.title2.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(Color.accentColor)
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
            .opacity(isPressed ? 0.65 : 1)
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginPress() }
                    .onEnded { _ in endPress() }
            )
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { tapAction() }
            .onDisappear { cancelPress() }
    }

    private func beginPress() {
        guard !isPressed else { return }
        isPressed = true
        isRepeating = false
        holdTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            isRepeating = true
            startContinuousMove()
        }
    }

    private func endPress() {
        holdTask?.cancel()
        holdTask = nil
        isPressed = false
        if isRepeating {
            isRepeating = false
            stopContinuousMove()
        } else {
            tapAction()
        }
    }

    private func cancelPress() {
        holdTask?.cancel()
        holdTask = nil
        stopContinuousMove()
    }
}

private struct BoardView: View {
    let board: [[TetrominoKind?]]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width / CGFloat(TetrisGame.columns), proxy.size.height / CGFloat(TetrisGame.rows))
            let width = side * CGFloat(TetrisGame.columns)
            let height = side * CGFloat(TetrisGame.rows)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: width, height: height)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(uiColor: .separator), lineWidth: 1))
                ForEach(0..<TetrisGame.rows, id: \.self) { row in
                    ForEach(0..<TetrisGame.columns, id: \.self) { column in
                        let kind = board[row][column]
                        RoundedRectangle(cornerRadius: max(2, side * 0.12))
                            .fill(color(for: kind))
                            .overlay(
                                RoundedRectangle(cornerRadius: max(2, side * 0.12))
                                    .stroke(
                                        kind == nil ? Color(uiColor: .separator).opacity(0.85) : .white.opacity(0.65),
                                        lineWidth: kind == nil ? max(1, side * 0.035) : 1.25
                                    )
                            )
                            .frame(width: side - 1, height: side - 1)
                            .offset(x: CGFloat(column) * side + 0.5, y: CGFloat(row) * side + 0.5)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(CGFloat(TetrisGame.columns) / CGFloat(TetrisGame.rows), contentMode: .fit)
        .accessibilityLabel("Tetris board")
    }
}

private struct PiecePreview: View {
    let kind: TetrominoKind

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width / 4, proxy.size.height / 4)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: .secondarySystemBackground))
                ForEach(Array(kind.cells(rotation: 0).enumerated()), id: \.offset) { _, cell in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: kind))
                        .frame(width: side - 2, height: side - 2)
                        .offset(x: CGFloat(cell.0) * side + side / 2, y: CGFloat(cell.1) * side + side / 2)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private func color(for kind: TetrominoKind?) -> Color {
    switch kind {
    case .i: .cyan
    case .o: .yellow
    case .t: .purple
    case .s: .green
    case .z: .red
    case .j: .blue
    case .l: .orange
    case nil: Color(uiColor: .systemBackground)
    }
}
