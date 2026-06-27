# Brick

一个原生 SwiftUI 俄罗斯方块游戏，使用适合手机单屏游玩的 10 × 18 棋盘。分数和消行数只反映表现；它们**不会**改变下落速度。玩家可在 `Slow`、`Normal`、`Fast` 三档间随时手动切换速度。

## 在 Xcode 运行

1. 安装完整 Xcode（需要 iOS Simulator SDK），并打开 [Brick.xcodeproj](Brick.xcodeproj)。
2. 选择任一 iPhone 模拟器后运行 `Brick` scheme。
3. 点击底部按键可左右移动、旋转或硬降；长按左右按键可连续移动。顶部可暂停、重开、选择速度，并打开本机排行榜。

## 验证

- `BrickTests/GameEngineTests.swift` 是 Xcode 单元测试。
- `swift run GameLogicCheck` 是不依赖模拟器的游戏规则验证，覆盖消行计分不改变速度、游戏快照恢复、手动速度设置和暂停行为。
