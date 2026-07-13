import SwiftUI
import AppKit

struct DinoRunnerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var posY: CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var obstacles: [CGRect] = []
    @State private var distance: CGFloat = 0
    @State private var isPlaying = false
    @State private var isGameOver = false
    @State private var timer: Timer?
    @State private var isHovering = false

    private let groundY: CGFloat = 130
    private let dinoX: CGFloat = 60
    private let dinoW: CGFloat = 30
    private let dinoH: CGFloat = 36
    private let gravity: CGFloat = 0.5
    private let jumpForce: CGFloat = 8

    private var speed: CGFloat {
        let base: CGFloat = 2.5
        let increase = min(distance / 80, 4)
        return base + increase
    }

    private var minGap: CGFloat {
        let base: CGFloat = 280
        let reduction = min(distance * 1.2, 150)
        return base - reduction
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(String(format: "%.0f", distance)) 米")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("速度 \(String(format: "%.1f", speed))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Canvas { ctx, size in
                ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: groundY)),
                         with: .color(Color.gray.opacity(0.1)))

                ctx.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: 2)),
                         with: .color(Color.gray.opacity(0.4)))

                for obs in obstacles {
                    ctx.fill(Path(roundedRect: obs, cornerRadius: 4),
                             with: .color(Color.red.opacity(0.7)))
                }

                let dinoRect = CGRect(x: dinoX, y: groundY - dinoH - posY, width: dinoW, height: dinoH)
                ctx.fill(Path(roundedRect: dinoRect, cornerRadius: 4),
                         with: .color(Color.blue))
                let eyeRect = CGRect(x: dinoX + dinoW - 10, y: groundY - dinoH - posY + 6, width: 6, height: 6)
                ctx.fill(Path(ellipseIn: eyeRect), with: .color(.white))
            }
            .frame(height: 160)
            .background(Color.white.opacity(0.02))
            .onTapGesture { jump() }
            .onHover { hovering in
                isHovering = hovering
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pointingHand.pop() }
            }
            .onAppear { startGame() }
            .onDisappear {
                timer?.invalidate()
                if isHovering { NSCursor.pointingHand.pop() }
            }

            HStack {
                if !isPlaying && !isGameOver {
                    Text("点击画面开始").foregroundStyle(.secondary)
                } else if isGameOver {
                    Text("跑了 \(String(format: "%.0f", distance)) 米！点击重新开始")
                        .foregroundStyle(.red)
                } else {
                    Text("点击或按空格跳跃").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .padding(.vertical, 6)
        }
        .frame(width: 380, height: 220)
        .onKeyPress(.space) {
            jump()
            return .handled
        }
    }

    private func startGame() {
        posY = 0
        velocity = 0
        obstacles = []
        distance = 0
        isPlaying = false
        isGameOver = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            update()
        }
    }

    private func jump() {
        if isGameOver {
            startGame()
            return
        }
        if !isPlaying { isPlaying = true }
        if posY <= 0 { velocity = jumpForce }
    }

    private func update() {
        guard isPlaying, !isGameOver else { return }

        velocity -= gravity
        posY += velocity
        if posY < 0 { posY = 0; velocity = 0 }

        obstacles = obstacles.compactMap { obs in
            var newObs = obs
            newObs.origin.x -= speed
            return newObs.maxX > -20 ? newObs : nil
        }

        let gap = minGap + CGFloat.random(in: 0...80)
        if obstacles.isEmpty || (obstacles.last?.minX ?? 0) < 380 - gap {
            let minH: CGFloat = 14
            let maxH: CGFloat = min(36, 18 + distance * 0.15)
            let h = CGFloat.random(in: minH...maxH)
            let obs = CGRect(x: 380, y: groundY - h, width: 14, height: h)
            obstacles.append(obs)
        }

        let dinoRect = CGRect(x: dinoX, y: groundY - dinoH - posY, width: dinoW, height: dinoH)
        for obs in obstacles {
            if dinoRect.intersects(obs.insetBy(dx: -2, dy: -2)) {
                isGameOver = true
                isPlaying = false
                return
            }
        }

        distance += speed / 60
    }
}
