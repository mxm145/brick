import Foundation

struct ScoreEntry: Codable, Identifiable {
    let id: UUID
    let score: Int
    let lines: Int
    let date: Date
}

enum GamePersistence {
    private static let gameKey = "savedGame"
    private static let leaderboardKey = "leaderboard"

    static func loadGame() -> TetrisGame? {
        guard let data = UserDefaults.standard.data(forKey: gameKey),
              let snapshot = try? JSONDecoder().decode(TetrisGameSnapshot.self, from: data) else { return nil }
        return TetrisGame(snapshot: snapshot)
    }

    static func save(_ game: TetrisGame) {
        guard let data = try? JSONEncoder().encode(game.snapshot) else { return }
        UserDefaults.standard.set(data, forKey: gameKey)
    }

    static func loadLeaderboard() -> [ScoreEntry] {
        guard let data = UserDefaults.standard.data(forKey: leaderboardKey),
              let entries = try? JSONDecoder().decode([ScoreEntry].self, from: data) else { return [] }
        return entries
    }

    static func record(_ game: TetrisGame) -> [ScoreEntry] {
        guard game.score > 0 else { return loadLeaderboard() }
        var entries = loadLeaderboard()
        entries.append(ScoreEntry(id: UUID(), score: game.score, lines: game.lines, date: .now))
        entries.sort {
            $0.score == $1.score ? $0.lines > $1.lines : $0.score > $1.score
        }
        entries = Array(entries.prefix(5))
        guard let data = try? JSONEncoder().encode(entries) else { return entries }
        UserDefaults.standard.set(data, forKey: leaderboardKey)
        return entries
    }
}
