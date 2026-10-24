import SwiftUI

/// Launch splash: oil drops fall from a nozzle that tracks across the screen
/// like a print head, assembling the word "oktan" in dot-matrix letters.
/// Drops swell at the nozzle, detach, stretch as they accelerate, and settle
/// with a liquid wobble. A blur + alpha-threshold filter merges nearby drops
/// into a gooey liquid (metaballs).
struct SplashView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long the splash should stay up (one full animation run + a beat).
    static let minimumDisplayDuration: TimeInterval = 0.65
    /// Display duration when Reduce Motion is on.
    static let reducedMotionDisplayDuration: TimeInterval = 0.35

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if reduceMotion {
                // Static, calm variant
                VStack {
                    Image(systemName: "drop.fill")
                        .font(.largeTitle)
                        .foregroundStyle(settings.currentTheme.accent)
                    Text("oktan")
                        .font(settings.currentTheme.displayFont(relativeTo: .largeTitle))
                }
            } else {
                OilDropCanvas(oilColor: settings.currentTheme.accent)
                    .frame(maxWidth: 480)
                    .aspectRatio(640.0 / 300.0, contentMode: .fit)
                    .padding(.horizontal)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Oktan is loading")
    }
}

// MARK: - Animation Model

/// Precomputed choreography for the oil-drop animation, in a 640x300 space.
enum OilDropAnimation {
    struct Dot {
        let x: CGFloat
        let y: CGFloat
        let releaseTime: Double
        let fallDuration: Double
        var landTime: Double { releaseTime + fallDuration }
    }

    // 5x7 dot-matrix letterforms
    private static let glyphs: [Character: [String]] = [
        "o": ["     ", "     ", " ### ", "#   #", "#   #", "#   #", " ### "],
        "k": ["#    ", "#    ", "#  # ", "# #  ", "##   ", "# #  ", "#  # "],
        "t": [" #   ", " #   ", "#### ", " #   ", " #   ", " #   ", "  ## "],
        "a": ["     ", "     ", " ### ", "    #", " ####", "#   #", " ####"],
        "n": ["     ", "     ", "# ## ", "##  #", "#   #", "#   #", "#   #"]
    ]

    static let canvasSize = CGSize(width: 640, height: 300)
    static let cell: CGFloat = 16
    static let dotRadius: CGFloat = 5.6
    static let nozzleY: CGFloat = 64
    static let gridTop: CGFloat = 118
    static let gravity: CGFloat = 1500
    static let releaseInterval: Double = 0.055
    static let swellDuration: Double = 0.1

    /// All dots for "oktan", ordered column-by-column (left to right).
    static let dots: [Dot] = {
        let word = "oktan"
        var raw: [(x: CGFloat, y: CGFloat, col: Int, row: Int)] = []
        for (letterIndex, letter) in word.enumerated() {
            guard let rows = glyphs[letter] else { continue }
            for column in 0..<5 {
                for row in 0..<7 where Array(rows[row])[column] == "#" {
                    let globalColumn = letterIndex * 7 + column
                    raw.append((
                        x: 56 + CGFloat(globalColumn) * cell + cell / 2,
                        y: gridTop + CGFloat(row) * cell,
                        col: globalColumn,
                        row: row
                    ))
                }
            }
        }
        raw.sort { ($0.col, $0.row) < ($1.col, $1.row) }
        return raw.enumerated().map { index, dot in
            let releaseTime = 0.3 + Double(index) * releaseInterval
            let fallDuration = Double(sqrt(2 * (dot.y - nozzleY) / gravity))
            return Dot(x: dot.x, y: dot.y, releaseTime: releaseTime, fallDuration: fallDuration)
        }
    }()

    /// Time from start until the last dot has settled.
    static let totalDuration: Double = (dots.last?.landTime ?? 3.0) + 0.8
}

// MARK: - Canvas

private struct OilDropCanvas: View {
    let oilColor: Color

    /// @State so parent re-renders (e.g. when app init finishes) don't reset
    /// the animation clock mid-run.
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                let space = OilDropAnimation.canvasSize
                let scale = min(size.width / space.width, size.height / space.height)
                context.translateBy(
                    x: (size.width - space.width * scale) / 2,
                    y: (size.height - space.height * scale) / 2
                )
                context.scaleBy(x: scale, y: scale)

                let t = min(elapsed, OilDropAnimation.totalDuration)
                let dots = OilDropAnimation.dots

                // Nozzle position tracks the dot currently being released
                let currentIndex = max(0, min(dots.count - 1, Int((t - 0.3) / OilDropAnimation.releaseInterval) + 1))
                let nozzleX = t >= OilDropAnimation.totalDuration - 0.8
                    ? dots[dots.count - 1].x
                    : dots[currentIndex].x

                drawNozzle(context: &context, x: nozzleX)

                // Gooey liquid layer: blur + alpha threshold = metaballs
                var liquid = context
                liquid.addFilter(.alphaThreshold(min: 0.5, color: oilColor))
                liquid.addFilter(.blur(radius: 4))
                liquid.drawLayer { layer in
                    for dot in dots {
                        drawDot(dot, at: t, nozzleX: nozzleX, in: &layer)
                    }
                }
            }
        }
    }

    private func drawNozzle(context: inout GraphicsContext, x: CGFloat) {
        let nozzleColor = Color.secondary
        let bodyRect = CGRect(x: x - 14, y: OilDropAnimation.nozzleY - 38, width: 28, height: 18)
        context.fill(Path(roundedRect: bodyRect, cornerRadius: 3), with: .color(nozzleColor))

        var tip = Path()
        tip.move(to: CGPoint(x: x - 8, y: OilDropAnimation.nozzleY - 20))
        tip.addLine(to: CGPoint(x: x + 8, y: OilDropAnimation.nozzleY - 20))
        tip.addLine(to: CGPoint(x: x + 4, y: OilDropAnimation.nozzleY - 6))
        tip.addLine(to: CGPoint(x: x - 4, y: OilDropAnimation.nozzleY - 6))
        tip.closeSubpath()
        context.fill(tip, with: .color(nozzleColor))
    }

    private func drawDot(_ dot: OilDropAnimation.Dot, at t: Double, nozzleX: CGFloat, in layer: inout GraphicsContext) {
        let radius = OilDropAnimation.dotRadius
        let swellStart = dot.releaseTime - OilDropAnimation.swellDuration
        guard t >= swellStart else { return }

        if t < dot.releaseTime {
            // Swelling at the nozzle tip
            let progress = CGFloat((t - swellStart) / OilDropAnimation.swellDuration)
            fillTeardrop(
                center: CGPoint(x: nozzleX, y: OilDropAnimation.nozzleY + progress * 3),
                radius: radius * (0.35 + 0.65 * progress),
                stretch: 0.3 * progress,
                in: &layer
            )
        } else if t < dot.landTime {
            // Free fall with velocity stretch
            let fallTime = CGFloat(t - dot.releaseTime)
            let y = OilDropAnimation.nozzleY + 0.5 * OilDropAnimation.gravity * fallTime * fallTime
            let velocity = OilDropAnimation.gravity * fallTime
            fillTeardrop(
                center: CGPoint(x: dot.x, y: y),
                radius: radius,
                stretch: min(velocity / 900, 0.8),
                in: &layer
            )
        } else {
            // Landed: decaying liquid wobble
            let settle = t - dot.landTime
            let spring = 1 + 0.45 * exp(-settle * 5) * sin(settle * 22)
            let squash = CGFloat(max(0.55, min(1.45, spring)))
            let rx = radius * (2 - squash) * 0.9 + radius * 0.1
            let rect = CGRect(
                x: dot.x - rx,
                y: dot.y - radius * squash,
                width: 2 * rx,
                height: 2 * radius * squash
            )
            layer.fill(Path(ellipseIn: rect), with: .color(.black))
        }
    }

    private func fillTeardrop(center: CGPoint, radius: CGFloat, stretch: CGFloat, in layer: inout GraphicsContext) {
        let rx = radius * (1 - 0.3 * stretch)
        let ry = radius * (1 + 0.8 * stretch)
        let rect = CGRect(x: center.x - rx, y: center.y - ry, width: 2 * rx, height: 2 * ry)
        layer.fill(Path(ellipseIn: rect), with: .color(.black))
    }
}

#Preview {
    SplashView()
        .environment(AppSettings())
}
