import SwiftUI

struct SplashView: View {
    // Configuration for each oil drop
    struct DropConfig {
        let char: String
        let offset: CGFloat       // X Position (Vertical fall, so startX = targetX)
        let size: CGFloat         // Size of the drop
        let delay: Double         // Start delay
        let fallDuration: Double  // How fast it falls (Gravity/Viscosity illusion)
    }
    
    // Configured for "oktan"
    // Drops fall STRAIGT DOWN from the Island area.
    // Spacing reduced slightly to keep them clustered under the island.
    // o/a smaller, k/t/n larger.
    let drops: [DropConfig] = [
        DropConfig(char: "o", offset: -80, size: 18, delay: 0.1, fallDuration: 0.55),
        DropConfig(char: "k", offset: -40, size: 26, delay: 0.6, fallDuration: 0.45), // Larger falls faster?
        DropConfig(char: "t", offset: 0,   size: 28, delay: 0.3, fallDuration: 0.45),
        DropConfig(char: "a", offset: 40,  size: 18, delay: 0.9, fallDuration: 0.55),
        DropConfig(char: "n", offset: 80,  size: 26, delay: 0.5, fallDuration: 0.50)
    ]
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                
                // Assuming Dynamic Island bottom is around y=65 roughly.
                let startY: CGFloat = 65
                
                ForEach(drops.indices, id: \.self) { index in
                    let config = drops[index]
                    OilDropView(
                        config: config,
                        xPosition: centerX + config.offset,
                        startY: startY,
                        targetY: centerY
                    )
                }
            }
        }
    }
}

struct OilDropView: View {
    let config: SplashView.DropConfig
    let xPosition: CGFloat
    let startY: CGFloat
    let targetY: CGFloat
    
    // Animation States
    // Start at top
    @State private var yPosition: CGFloat
    @State private var dropScale: CGSize = CGSize(width: 0.1, height: 0.1) // Growing phase
    @State private var isSplashed = false
    
    // Letter & Splash States
    @State private var letterScale: CGFloat = 0.5
    @State private var letterOpacity: Double = 0.0
    @State private var splashScale: CGFloat = 0.5
    @State private var splashOpacity: Double = 0.8
    
    init(config: SplashView.DropConfig, xPosition: CGFloat, startY: CGFloat, targetY: CGFloat) {
        self.config = config
        self.xPosition = xPosition
        self.startY = startY
        self.targetY = targetY
        self._yPosition = State(initialValue: startY)
    }
    
    var body: some View {
        ZStack {
            if !isSplashed {
                // FALLING OIL DROP
                DropShape()
                    .fill(Color.black)
                    .frame(width: config.size, height: config.size * 1.5)
                    .scaleEffect(dropScale, anchor: .top) // Grow from top
                    .position(x: xPosition, y: yPosition)
            } else {
                // IMPACT SPLASH
                Circle()
                    .stroke(Color.black, lineWidth: 2.5)
                    .frame(width: config.size, height: config.size)
                    .scaleEffect(splashScale)
                    .opacity(splashOpacity)
                    .position(x: xPosition, y: targetY)
                
                // LETTER
                Text(config.char)
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)
                    .position(x: xPosition, y: targetY)
                    .scaleEffect(letterScale)
                    .opacity(letterOpacity)
            }
        }
        .task {
            // Sequence:
            // 1. Wait Delay
            // 2. Form (Grow) at Top
            // 3. Fall (Gravity)
            // 4. Splash
            
            // 1. Delay
            if config.delay > 0 {
                try? await Task.sleep(for: .seconds(config.delay))
            }
            
            // 2. Form - "Swell" slowly
            // Anchor is top, so it elongates down
            withAnimation(.easeInOut(duration: 1.0)) {
                dropScale = CGSize(width: 1.0, height: 1.0)
            }
            
            // Wait for full formation + Moment of suspense?
            try? await Task.sleep(for: .seconds(0.9))
            
            // 3. Fall
            // EaseIn simulates gravity acceleration
            withAnimation(.easeIn(duration: config.fallDuration)) {
                yPosition = targetY
            }
            
            // Wait for impact
            // Note: Animation time is approximate, we sleep slightly less to trigger splash exactly on hit
            try? await Task.sleep(for: .seconds(config.fallDuration - 0.05))
            
            // 4. Impact
            isSplashed = true
            
            // Splash Ring Expand & Fade
            withAnimation(.easeOut(duration: 0.4)) {
                splashScale = 2.5
                splashOpacity = 0.0
            }
            
            // Letter Appear (No bounce/jump, just smooth scaling)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                letterScale = 1.0
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
