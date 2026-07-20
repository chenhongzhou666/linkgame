import SwiftUI

// MARK: - StickFigureArena

struct StickFigureArena: View {
    let myName: String
    let opponentName: String
    let myHP: Int
    let opponentHP: Int
    let maxHP: Int
    var isShooting: Bool = false       // 正在射箭
    var isTakingHit: Bool = false      // 我方被射中

    var body: some View {
        HStack(spacing: 0) {
            // 我方
            playerSide(
                name: myName,
                hp: myHP,
                color: .blue,
                facingRight: true,
                isShooting: isShooting,
                isTakingHit: isTakingHit
            )

            // 中间分隔
            VStack(spacing: 8) {
                // 箭飞行动画区域
                ZStack {
                    if isShooting {
                        arrowFlying(fromLeft: true)
                    } else if isTakingHit {
                        arrowFlying(fromLeft: false)
                    }
                }
                .frame(width: 60, height: 40)

                Text("VS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)

            // 对手
            playerSide(
                name: opponentName,
                hp: opponentHP,
                color: .red,
                facingRight: false,
                isShooting: isTakingHit,
                isTakingHit: isShooting
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Player Side

    private func playerSide(
        name: String, hp: Int, color: Color,
        facingRight: Bool, isShooting: Bool, isTakingHit: Bool
    ) -> some View {
        VStack(spacing: 8) {
            // 火柴人
            StickFigureView(
                color: color,
                facingRight: facingRight,
                isShooting: isShooting,
                isTakingHit: isTakingHit
            )
            .frame(width: 50, height: 70)

            // 名字
            Text(name)
                .font(.caption.bold())
                .lineLimit(1)

            // HP 条
            HPBar(current: hp, max: maxHP, color: color)
                .frame(width: 120, height: 14)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Arrow Animation

    private func arrowFlying(fromLeft: Bool) -> some View {
        ArrowView()
            .stroke(.orange, lineWidth: 2)
            .frame(width: 40, height: 6)
            .offset(x: fromLeft ? 20 : -20)
    }

    struct ArrowView: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let midY = rect.midY
            p.move(to: CGPoint(x: 0, y: midY))
            p.addLine(to: CGPoint(x: rect.width - 8, y: midY))
            p.move(to: CGPoint(x: rect.width - 10, y: midY - 4))
            p.addLine(to: CGPoint(x: rect.width, y: midY))
            p.addLine(to: CGPoint(x: rect.width - 10, y: midY + 4))
            return p
        }
    }
}

// MARK: - StickFigureView

struct StickFigureView: View {
    let color: Color
    let facingRight: Bool
    var isShooting: Bool = false
    var isTakingHit: Bool = false

    @State private var shootingPhase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let headR: CGFloat = 7
            let headY = headR + 2
            let bodyTop = headY + headR
            let bodyLen: CGFloat = 22
            let bodyBot = bodyTop + bodyLen
            let armY = bodyTop + 6
            let legY = bodyBot

            // 朝向系数
            let dir: CGFloat = facingRight ? 1 : -1

            // 抖动
            var shakeX: CGFloat = 0
            if isTakingHit {
                shakeX = CGFloat.random(in: -3...3)
            }

            // 颜色
            let fillColor = color.opacity(0.8)

            // 头
            let headRect = CGRect(x: cx - headR + shakeX, y: headY - headR, width: headR * 2, height: headR * 2)
            context.fill(Path(ellipseIn: headRect), with: .color(fillColor))

            // 身体
            let bodyPath = Path { p in
                p.move(to: CGPoint(x: cx + shakeX, y: bodyTop))
                p.addLine(to: CGPoint(x: cx + shakeX, y: bodyBot))
            }
            context.stroke(bodyPath, with: .color(fillColor), lineWidth: 2.5)

            // 手臂 - 持弓手朝前
            let frontArmEnd = CGPoint(x: cx + dir * 16 + shakeX, y: armY)
            let backArmEnd = CGPoint(x: cx - dir * (isShooting ? 18 : 12) + shakeX, y: armY)

            let frontArm = Path { p in
                p.move(to: CGPoint(x: cx + shakeX, y: armY))
                p.addLine(to: frontArmEnd)
            }
            context.stroke(frontArm, with: .color(fillColor), lineWidth: 2)

            let backArm = Path { p in
                p.move(to: CGPoint(x: cx + shakeX, y: armY))
                p.addLine(to: backArmEnd)
            }
            context.stroke(backArm, with: .color(fillColor), lineWidth: 2)

            // 弓（持弓手前端的小弧）
            let bowPath = Path { p in
                let bowX = frontArmEnd.x
                let bowY = frontArmEnd.y
                p.move(to: CGPoint(x: bowX, y: bowY - 8))
                p.addQuadCurve(
                    to: CGPoint(x: bowX, y: bowY + 8),
                    control: CGPoint(x: bowX + dir * 6, y: bowY)
                )
            }
            context.stroke(bowPath, with: .color(.brown), lineWidth: 1.5)

            // 箭（拉弦时出现）
            if isShooting {
                let arrowPath = Path { p in
                    p.move(to: CGPoint(x: backArmEnd.x, y: armY))
                    p.addLine(to: CGPoint(x: frontArmEnd.x, y: frontArmEnd.y))
                }
                context.stroke(arrowPath, with: .color(.orange), lineWidth: 1.5)

                // 箭头
                let tipRect = CGRect(x: frontArmEnd.x - 3, y: frontArmEnd.y - 2, width: 6, height: 4)
                context.fill(Path(ellipseIn: tipRect), with: .color(.orange))
            }

            // 腿
            let leftLeg = Path { p in
                p.move(to: CGPoint(x: cx + shakeX, y: legY))
                p.addLine(to: CGPoint(x: cx - 7 + shakeX, y: legY + 14))
            }
            context.stroke(leftLeg, with: .color(fillColor), lineWidth: 2)

            let rightLeg = Path { p in
                p.move(to: CGPoint(x: cx + shakeX, y: legY))
                p.addLine(to: CGPoint(x: cx + 7 + shakeX, y: legY + 14))
            }
            context.stroke(rightLeg, with: .color(fillColor), lineWidth: 2)
        }
        .frame(width: 50, height: 70)
    }
}

// MARK: - HPBar

struct HPBar: View {
    let current: Int
    let max: Int
    let color: Color

    var ratio: CGFloat {
        max > 0 ? CGFloat(current) / CGFloat(max) : 0
    }

    var barColor: Color {
        if ratio > 0.5 { return color }
        if ratio > 0.25 { return .orange }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: geo.size.height)

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geo.size.width * ratio, height: geo.size.height)
                    .animation(.easeInOut(duration: 0.4), value: ratio)
            }
        }
        .overlay(
            Text("\(current)/\(max)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(radius: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StickFigureArena(
            myName: "我的昵称",
            opponentName: "对手昵称",
            myHP: 88,
            opponentHP: 100,
            maxHP: 100,
            isShooting: true
        )

        StickFigureArena(
            myName: "玩家A",
            opponentName: "玩家B",
            myHP: 50,
            opponentHP: 30,
            maxHP: 100,
            isTakingHit: true
        )
    }
    .padding()
    .frame(width: 500, height: 400)
}
