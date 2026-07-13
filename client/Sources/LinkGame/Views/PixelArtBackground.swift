import SwiftUI

// MARK: - Wallpaper-Aware Background Wrapper

struct PixelArtBackground: View {
    @StateObject private var wallpaper = WallpaperManager.shared

    var body: some View {
        switch wallpaper.current {
        case .pixelArt:
            PixelArtScene()
        case .gradient:
            AppBackground()
        }
    }
}

// MARK: - Pixel Art Animated Scene

struct PixelArtScene: View {
    let pixelSize: CGFloat = 8

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let cols = Int(size.width / pixelSize) + 1
                let rows = Int(size.height / pixelSize) + 1
                drawSky(context: &context, cols: cols, rows: rows, ps: pixelSize)
                drawClouds(context: &context, cols: cols, rows: rows, ps: pixelSize, t: t)
                drawGrass(context: &context, cols: cols, rows: rows, ps: pixelSize, t: t)
                drawWindmill(context: &context, cols: cols, rows: rows, ps: pixelSize, t: t, centerCol: 8, phaseOffset: 0)
                drawWindmill(context: &context, cols: cols, rows: rows, ps: pixelSize, t: t, centerCol: cols - 8, phaseOffset: .pi / 3)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Sky

    func drawSky(context: inout GraphicsContext, cols: Int, rows: Int, ps: CGFloat) {
        let skyColors: [Color] = [
            Color(red: 0.25, green: 0.50, blue: 0.82),
            Color(red: 0.30, green: 0.56, blue: 0.85),
            Color(red: 0.36, green: 0.62, blue: 0.88),
            Color(red: 0.42, green: 0.68, blue: 0.90),
            Color(red: 0.48, green: 0.73, blue: 0.92),
            Color(red: 0.55, green: 0.78, blue: 0.94),
            Color(red: 0.62, green: 0.82, blue: 0.95),
            Color(red: 0.70, green: 0.86, blue: 0.96),
        ]
        let bandHeight = 2
        let grassStartRow = rows - 16
        var row = 0
        var ci = 0
        while row < grassStartRow {
            let color = skyColors[min(ci, skyColors.count - 1)]
            let rect = CGRect(x: 0, y: CGFloat(row) * ps, width: CGFloat(cols) * ps, height: CGFloat(bandHeight) * ps)
            context.fill(Path(rect), with: .color(color))
            row += bandHeight
            ci += 1
        }
        if row < grassStartRow {
            let rect = CGRect(x: 0, y: CGFloat(row) * ps, width: CGFloat(cols) * ps, height: CGFloat(grassStartRow - row) * ps)
            context.fill(Path(rect), with: .color(skyColors.last!))
        }
    }

    // MARK: - Clouds

    struct CloudDef {
        let pattern: [(dc: Int, dr: Int, shadow: Bool)]
        let speed: Double
        let pixelRow: Int
        let pixelWidth: Int
    }

    static let clouds: [CloudDef] = [
        CloudDef(pattern: [
            (1,0,false), (2,0,false), (3,0,false),
            (0,1,false), (1,1,false), (2,1,false), (3,1,false), (4,1,false),
            (1,2,true),  (2,2,true),  (3,2,true),
        ], speed: 1.2, pixelRow: 6, pixelWidth: 5),
        CloudDef(pattern: [
            (1,0,false), (2,0,false), (3,0,false), (4,0,false),
            (0,1,false), (1,1,false), (2,1,false), (3,1,false), (4,1,false), (5,1,false),
            (0,2,false), (1,2,false), (2,2,false), (3,2,false), (4,2,false), (5,2,false),
            (1,3,true),  (2,3,true),  (3,3,true),  (4,3,true),
        ], speed: 0.8, pixelRow: 14, pixelWidth: 6),
        CloudDef(pattern: [
            (2,0,false), (3,0,false), (4,0,false), (5,0,false),
            (1,1,false), (2,1,false), (3,1,false), (4,1,false), (5,1,false), (6,1,false),
            (0,2,false), (1,2,false), (2,2,false), (3,2,false), (4,2,false), (5,2,false), (6,2,false), (7,2,false),
            (0,3,false), (1,3,false), (2,3,false), (3,3,false), (4,3,false), (5,3,false), (6,3,false),
            (2,4,true),  (3,4,true),  (4,4,true),  (5,4,true),
        ], speed: 1.4, pixelRow: 23, pixelWidth: 8),
        CloudDef(pattern: [
            (1,0,false), (2,0,false), (3,0,false),
            (0,1,false), (1,1,false), (2,1,false), (3,1,false), (4,1,false),
            (1,2,true),  (2,2,true),  (3,2,true),
        ], speed: 0.9, pixelRow: 10, pixelWidth: 5),
    ]

    func drawClouds(context: inout GraphicsContext, cols: Int, rows: Int, ps: CGFloat, t: TimeInterval) {
        let white = Color.white
        let shadow = Color(red: 0.82, green: 0.88, blue: 0.94)

        for cloud in Self.clouds {
            let totalW = CGFloat(cols + cloud.pixelWidth)
            let offset = t / cloud.speed
            let x = totalW - offset.truncatingRemainder(dividingBy: totalW) - CGFloat(cloud.pixelWidth)
            let bc = Int(x)

            for (dc, dr, isShadow) in cloud.pattern {
                let col = bc + dc
                if col < 0 || col >= cols { continue }
                let rect = CGRect(x: CGFloat(col) * ps, y: CGFloat(cloud.pixelRow + dr) * ps, width: ps, height: ps)
                context.fill(Path(rect), with: .color(isShadow ? shadow : white))
            }
        }
    }

    // MARK: - Grass

    func drawGrass(context: inout GraphicsContext, cols: Int, rows: Int, ps: CGFloat, t: TimeInterval) {
        let grassRows = 16
        let startRow = rows - grassRows

        let darkGreen  = Color(red: 0.13, green: 0.55, blue: 0.13)
        let midGreen   = Color(red: 0.20, green: 0.65, blue: 0.20)
        let lightGreen = Color(red: 0.30, green: 0.75, blue: 0.30)
        let brightGreen = Color(red: 0.40, green: 0.85, blue: 0.35)

        for row in (startRow + 3)..<rows {
            for col in 0..<cols {
                let shade: Color = switch (col + row) % 4 {
                case 0: darkGreen
                case 1, 2: midGreen
                default: lightGreen
                }
                let rect = CGRect(x: CGFloat(col) * ps, y: CGFloat(row) * ps, width: ps, height: ps)
                context.fill(Path(rect), with: .color(shade))
            }
        }

        let swayAmp = 0.8
        for row in startRow..<(startRow + 3) {
            for col in 0..<cols {
                let relRow = row - startRow
                let swayFactor: Double = relRow == 0 ? 1.0 : (relRow == 1 ? 0.5 : 0.2)
                let sway = Int(sin(t * 2.2 + Double(col) * 0.4) * swayAmp * swayFactor)
                let sc = max(0, min(cols - 1, col + sway))

                let isGap = (col * 7 + row * 13) % 5 == 0
                if !isGap {
                    let color: Color = relRow == 0 ? brightGreen : (relRow == 1 ? lightGreen : midGreen)
                    let rect = CGRect(x: CGFloat(sc) * ps, y: CGFloat(row) * ps, width: ps, height: ps)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    // MARK: - Windmill (small, positioned by centerCol)

    func drawWindmill(context: inout GraphicsContext, cols: Int, rows: Int, ps: CGFloat, t: TimeInterval,
                      centerCol: Int, phaseOffset: Double) {
        let grassStartRow = rows - 16
        let bodyHeight = 12
        let bodyTop = grassStartRow - bodyHeight
        let bodyBot = grassStartRow + 4
        let hubRow = bodyTop

        let bodyDark  = Color(red: 0.35, green: 0.18, blue: 0.06)
        let bladeFill = Color(red: 0.94, green: 0.91, blue: 0.84)
        let bladeEdge = Color(red: 0.50, green: 0.28, blue: 0.10)

        // Body (thin pole, 1 column wide)
        for row in bodyTop..<bodyBot {
            let rect = CGRect(x: CGFloat(centerCol) * ps, y: CGFloat(row) * ps, width: ps, height: ps)
            context.fill(Path(rect), with: .color(bodyDark))
        }

        // Hub (2x2)
        for dr in 0...1 {
            for dc in 0...1 {
                let rect = CGRect(x: CGFloat(centerCol + dc) * ps, y: CGFloat(hubRow + dr) * ps, width: ps, height: ps)
                context.fill(Path(rect), with: .color(bladeEdge))
            }
        }

        // Rotating blades
        let hubX = CGFloat(centerCol) * ps + ps
        let hubY = CGFloat(hubRow) * ps + ps

        for i in 0..<4 {
            let bladeAngle = t * 1.6 + phaseOffset + Double(i) * .pi / 2
            drawBlade(context: &context, hubX: hubX, hubY: hubY, angle: bladeAngle,
                      ps: ps, fill: bladeFill, edge: bladeEdge)
        }
    }

    func drawBlade(context: inout GraphicsContext, hubX: CGFloat, hubY: CGFloat, angle: Double,
                   ps: CGFloat, fill: Color, edge: Color) {
        let bladeLen: CGFloat = 7 * ps
        let bladeHW: CGFloat = 1.5 * ps
        let gap: CGFloat = 1 * ps

        func rot(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let cosA = cos(angle)
            let sinA = sin(angle)
            return CGPoint(x: hubX + x * cosA - y * sinA,
                           y: hubY + x * sinA + y * cosA)
        }

        let bl = rot(gap, -bladeHW)
        let br = rot(gap + bladeLen, -bladeHW)
        let tr = rot(gap + bladeLen, bladeHW)
        let tl = rot(gap, bladeHW)

        var body = Path()
        body.move(to: bl); body.addLine(to: br)
        body.addLine(to: tr); body.addLine(to: tl)
        body.closeSubpath()
        context.fill(body, with: .color(fill))

        var outline = Path()
        outline.move(to: bl); outline.addLine(to: br)
        outline.addLine(to: tr); outline.addLine(to: tl)
        outline.closeSubpath()
        context.stroke(outline, with: .color(edge), lineWidth: 1)
    }
}

// MARK: - Wallpaper Picker Button

struct WallpaperButton: View {
    @StateObject private var manager = WallpaperManager.shared

    var body: some View {
        Menu {
            ForEach(Wallpaper.allCases, id: \.self) { wp in
                Button {
                    manager.current = wp
                } label: {
                    HStack {
                        Image(systemName: wp.icon)
                        Text(wp.rawValue)
                        if manager.current == wp {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: manager.current.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28)
    }
}
