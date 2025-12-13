import SwiftUI

struct SplashView: View {
    // Configuration for each drop
    struct DropConfig {
        let char: String
        let landX: CGFloat        // Random landing spot under island
        let finalX: CGFloat       // Final sorted position
        let size: CGFloat         // Drop size
        let delay: Double         // Start delay
        let formDuration: Double  // Time to balloon/form
        let fallDuration: Double  // Time to fall
    }
    
    // "oktan" -> 5 letters
    // Island Width ~120pt -> Random X between -50...50
    // Drops fall at different times for organic feel
    let drops: [DropConfig] = [
        DropConfig(char: "o", landX: -15, finalX: -85, size: 22, delay: 0.2, formDuration: 1.4, fallDuration: 0.65),
        DropConfig(char: "k", landX: -35, finalX: -45, size: 28, delay: 0.8, formDuration: 1.1, fallDuration: 0.50),
        DropConfig(char: "t", landX: 10,  finalX: -5,  size: 30, delay: 0.5, formDuration: 1.5, fallDuration: 0.55),
        DropConfig(char: "a", landX: 40,  finalX: 35,  size: 20, delay: 1.4, formDuration: 1.0, fallDuration: 0.60),
        DropConfig(char: "n", landX: -5,  finalX: 75,  size: 25, delay: 1.0, formDuration: 1.2, fallDuration: 0.52)
    ]
    
    @State private var isAligned = false
    
    var body: some View {
        ZStack {
            // Background matching new minimalist aesthetic (Silver/White Gradient)
            LinearGradient(
                colors: [Color.white, Color(uiColor: UIColor.systemGray5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                
                // We respect Safe Area (GeometryReader starts below Island).
                // "As high as possible" = Top of Safe Area (0).
                // We set -2 to ensure they emerge right from the border line.
                let startY: CGFloat = -2
                
                ForEach(drops.indices, id: \.self) { index in
                    let config = drops[index]
                    OilDropView(
                        config: config,
                        centerX: centerX,
                        startY: startY,
                        targetY: centerY,
                        isAligned: isAligned
                    )
                }
            }
        }
        .task {
            // Wait for all drops to splash and settle
            // Max timing is roughly 3.0s, giving 0.5s buffer
            try? await Task.sleep(for: .seconds(3.5))
            
            // Trigger Alignment (Letters slide to 'oktan')
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0)) {
                isAligned = true
            }
        }
    }
}

struct OilDropView: View {
    let config: SplashView.DropConfig
    let centerX: CGFloat
    let startY: CGFloat
    let targetY: CGFloat
    let isAligned: Bool
    
    // Animation States
    @State private var yPos: CGFloat
    @State private var scale: CGSize = CGSize(width: 0.1, height: 0.1)
    @State private var isSplashed = false
    @State private var letterOpacity: Double = 0.0
    @State private var splashOpacity: Double = 0.5
    @State private var splashScale: CGFloat = 0.2
    
    init(config: SplashView.DropConfig, centerX: CGFloat, startY: CGFloat, targetY: CGFloat, isAligned: Bool) {
        self.config = config
        self.centerX = centerX
        self.startY = startY
        self.targetY = targetY
        self.isAligned = isAligned
        self._yPos = State(initialValue: startY)
    }
    
    var body: some View {
        ZStack {
            if !isSplashed {
                // FALLING DROP
                // Custom shape for "dripping" - Using system drop image for consistency
                Image(systemName: "drop.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: config.size, height: config.size * 1.4)
                    .foregroundStyle(.black)
                    .scaleEffect(scale, anchor: .top)
                    .position(x: centerX + config.landX, y: yPos)
            } else {
                // SPLASH + LETTER
                ZStack {
                    // Splash Ring
                    Circle()
                        .stroke(.black, lineWidth: 2)
                        .frame(width: config.size * 0.8, height: config.size * 0.8)
                        .scaleEffect(splashScale)
                        .opacity(splashOpacity)
                    
                    // Letter
                    Text(config.char)
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .scaleEffect(isAligned ? 1.0 : 0.8) // Grow slightly when aligned
                        .rotationEffect(.degrees(isAligned ? 0 : Double.random(in: -15...15))) // Scrambled rotation
                }
                .position(
                    x: centerX + (isAligned ? config.finalX : config.landX),
                    y: targetY
                )
            }
        }
        .task {
            // Sequence:
            // 1. Delay
            if config.delay > 0 {
                try? await Task.sleep(for: .seconds(config.delay))
            }
            
            // 2. Form (Balloon out from island)
            withAnimation(.easeInOut(duration: config.formDuration)) {
                scale = CGSize(width: 1.0, height: 1.0)
            }
            try? await Task.sleep(for: .seconds(config.formDuration + 0.1))
            
            // 3. Fall
            withAnimation(.easeIn(duration: config.fallDuration)) {
                yPos = targetY
            }
            try? await Task.sleep(for: .seconds(config.fallDuration))
            
            // 4. Splash
            isSplashed = true
            
            // Animate Splash Ring
            withAnimation(.easeOut(duration: 0.4)) {
                splashScale = 2.0
                splashOpacity = 0.0
            }
            
            // Show Letter
            withAnimation(.bouncy(duration: 0.3)) {
                letterOpacity = 1.0
            }
        }
    }
}

// Standard Teardrop
struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.65),
            control: CGPoint(x: w, y: h * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: w / 2, y: h),
            control1: CGPoint(x: w, y: h * 0.9),
            control2: CGPoint(x: w * 0.65, y: h)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.65),
            control1: CGPoint(x: w * 0.35, y: h),
            control2: CGPoint(x: 0, y: h * 0.9)
        )
        path.addQuadCurve(
            to: CGPoint(x: w / 2, y: 0),
            control: CGPoint(x: 0, y: h * 0.2)
        )
        return path
    }
}

#Preview {
    SplashView()
}
