import SwiftUI

struct SplashView: View {
    // Configuration for each letter's drop
    struct DropConfig {
        let char: String
        let targetOffset: CGFloat // Where the letter lands (X)
        let startOffset: CGFloat  // Where the drop drips from (X) relative to center
        let size: CGFloat         // Size of the drop
        let delay: Double         // When it starts forming
    }
    
    // Configured for "oktan"
    // o/a smaller, k/t/n larger.
    // Natural dispersion along dynamic island (approx width 120pt)
    let drops: [DropConfig] = [
        DropConfig(char: "o", targetOffset: -90, startOffset: -40, size: 18, delay: 0.0),
        DropConfig(char: "k", targetOffset: -45, startOffset: -20, size: 26, delay: 0.5),
        DropConfig(char: "t", targetOffset: 0,   startOffset: 0,   size: 28, delay: 0.2), // "t" drips earlyish
        DropConfig(char: "a", targetOffset: 45,  startOffset: 20,  size: 18, delay: 0.8),
        DropConfig(char: "n", targetOffset: 90,  startOffset: 40,  size: 26, delay: 0.4)
    ]
    
    var body: some View {
        ZStack {
            Color.white // Oil (black) on White background
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                
                // Dynamic Island area mask (invisible, just for reference logic)
                // Drops start around y: 60 (below notch/island)
                
                ForEach(drops.indices, id: \.self) { index in
                    let config = drops[index]
                    NaturalDropView(
                        config: config,
                        centerX: centerX,
                        targetY: centerY
                    )
                }
            }
        }
    }
}

struct NaturalDropView: View {
    let config: SplashView.DropConfig
    let centerX: CGFloat
    let targetY: CGFloat
    
    // Animation States
    @State private var offset: CGPoint
    @State private var scale: CGSize = CGSize(width: 0.1, height: 0.1) // Start tiny
    @State private var isSplashed = false
    @State private var letterScale: CGFloat = 0.5
    @State private var letterOpacity: Double = 0.0
    @State private var splashRadius: CGFloat = 0.0
    @State private var splashOpacity: Double = 1.0
    
    init(config: SplashView.DropConfig, centerX: CGFloat, targetY: CGFloat) {
        self.config = config
        self.centerX = centerX
        self.targetY = targetY
        // Start position
        let startX = centerX + config.startOffset
        self._offset = State(initialValue: CGPoint(x: startX, y: 55))
    }
    
    var body: some View {
        ZStack {
            if !isSplashed {
                // The Oil Drop
                DropShape()
                    .fill(Color.black)
                    .frame(width: config.size, height: config.size * 1.4)
                    .position(offset)
                    .scaleEffect(scale)
            } else {
                // Splash Ring
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: splashRadius, height: splashRadius)
                    .position(x: centerX + config.targetOffset, y: targetY)
                    .opacity(splashOpacity)
                
                // The Letter
                Text(config.char)
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)
                    .position(x: centerX + config.targetOffset, y: targetY)
                    .scaleEffect(letterScale)
                    .opacity(letterOpacity)
            }
        }
        .task {
            // 1. Initial Delay
            try? await Task.sleep(for: .seconds(config.delay))
            
            // 2. FORMING (Grow from "Dynamic Island")
            // It "swells" before dropping
            withAnimation(.easeInOut(duration: 0.8)) {
                scale = CGSize(width: 1.0, height: 1.0)
            }
            
            // Wait for form to complete
            try? await Task.sleep(for: .seconds(0.7))
            
            // 3. FALLING (Accelerate down)
            // Duration depends on distance, but ~0.6s feels heavy/oily
            let fallDuration = 0.6
            withAnimation(.easeIn(duration: fallDuration)) {
                // Fall towards target X and Y
                // X also interpolates from StartX to TargetX (wind/momentum)
                offset = CGPoint(x: centerX + config.targetOffset, y: targetY)
            }
            
            // Wait for impact
            try? await Task.sleep(for: .seconds(fallDuration - 0.05))
            
            // 4. SPLASH & IMPACT
            isSplashed = true
            splashRadius = config.size
            
            // Splash ripple out
            withAnimation(.easeOut(duration: 0.5)) {
                splashRadius = config.size * 3.0
                splashOpacity = 0.0
            }
            
            // Text morph/snap in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                letterScale = 1.0
                letterOpacity = 1.0
            }
        }
    }
}

// Re-using the teardrop shape
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
