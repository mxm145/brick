import SwiftUI
import UIKit

enum HorizontalMove {
    case left, right
}

@MainActor
final class GameController: ObservableObject {
    @Published private(set) var game = TetrisGame()
    @Published var timerToken = UUID()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private var continuousMoveTask: Task<Void, Never>?

    func start() {
        stopContinuousMove()
        game.start()
        timerToken = UUID()
    }

    func restart() {
        start()
        feedback()
    }

    func moveLeft() { move(.left, withFeedback: true) }
    func moveRight() { move(.right, withFeedback: true) }
    func rotate() { game.rotate(); feedback() }
    func hardDrop() { game.hardDrop(); feedback() }

    func togglePause() {
        stopContinuousMove()
        game.togglePause()
        feedback()
    }

    func setSpeed(_ speed: DropSpeed) {
        game.setSpeed(speed)
        timerToken = UUID()
        feedback()
    }

    func advance(by elapsed: TimeInterval) { game.advance(by: elapsed) }
    func queueLongBar() { game.queueLongBar(); feedback() }

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
        switch direction {
        case .left: game.moveLeft()
        case .right: game.moveRight()
        }
        if withFeedback { feedback() }
    }

    private func feedback() {
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
    }
}

struct ContentView: View {
    @StateObject private var controller = GameController()

    var body: some View {
        GeometryReader { proxy in
            let boardHeight = max(0, min(proxy.size.height - 222, (proxy.size.width - 32) * 2))
            let boardWidth = boardHeight * CGFloat(TetrisGame.columns) / CGFloat(TetrisGame.rows)

            VStack(spacing: 8) {
                header
                BoardView(board: controller.game.renderedBoard)
                    .frame(width: boardWidth, height: boardHeight)
                gameInfo
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
        .onAppear { controller.start() }
        .onDisappear { controller.stopContinuousMove() }
    }

    private var header: some View {
        HStack {
            metric("Score", value: controller.game.score.formatted())
            Divider().frame(height: 44)
            metric("Lines", value: controller.game.lines.formatted())
            Spacer()
            Button(action: controller.togglePause) {
                Image(systemName: controller.game.state == .paused ? "play.fill" : "pause.fill")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityLabel(controller.game.state == .paused ? "Resume game" : "Pause game")
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.monospacedDigit().weight(.semibold))
        }
    }

    private var gameInfo: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Next").font(.caption).foregroundStyle(.secondary)
                    Button("长条") { controller.queueLongBar() }
                        .font(.caption2.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Set next piece to I bar")
                }
                PiecePreview(kind: controller.game.next)
                    .frame(width: 52, height: 52)
            }
            .frame(width: 78)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Speed").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(action: controller.restart) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Restart game")
                }
                HStack(spacing: 5) {
                    ForEach(DropSpeed.allCases) { speed in
                        Button(speed.rawValue) { controller.setSpeed(speed) }
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(controller.game.speed == speed ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(controller.game.speed == speed ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            HorizontalMoveButton(
                icon: "arrow.right",
                label: "Move right",
                tapAction: controller.moveRight,
                startContinuousMove: { controller.startContinuousMove(.right) },
                stopContinuousMove: controller.stopContinuousMove
            )
            controlButton("arrow.clockwise", action: controller.rotate)
            controlButton("arrow.down", action: controller.hardDrop)
        }
    }

    private func controlButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.bordered)
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
