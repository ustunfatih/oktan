import SwiftUI

struct SplashView: View {
    @State private var animationReady = false
    
    // Letters for "oktan"
    // We'll calculate positions dynamically or fixed relative to center
    // Centered alignment: o k t a n
    // t is center.
    let letters = [
        (char: "o", offset: -95.0, delay: 0.0, size: 28.0),
        (char: "k", offset: -50.0, delay: 0.15, size: 24.0),
        (char: "t", offset: 0.0, delay: 0.3, size: 32.0),
        (char: "a", offset: 45.0, delay: 0.45, size: 26.0),
        (char: "n", offset: 95.0, delay: 0.6, size: 30.0)
    ]
    
    var body: some View {
        ZStack {
            Color.white // Force white background for oil contrast
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                
                ForEach(letters.indices, id: \.self) { index in
                    let item = letters[index]
                    DropLetterView(
                        char: item.char,
                        targetX: centerX + item.offset,
                        targetY: centerY,
                        dropSize: item.size,
                        delay: item.delay,
                        startPoint: CGPoint(x: centerX, y: 60) // Dynamic Island approx y
                    )
                }
            }
        }
    }
}

struct DropLetterView: View {
    let char: String
    let targetX: CGFloat
    let targetY: CGFloat
    let dropSize: CGFloat
    let delay: Double
    let startPoint: CGPoint
    
    @State private var position: CGPoint
    @State private var isSplashed = false
    @State private var dropScale: CGFloat = 1.0
    @State private var letterScale: CGFloat = 0.0
    @State private var splashScale: CGFloat = 0.0
    @State private var splashOpacity: Double = 1.0
    
    init(char: String, targetX: CGFloat, targetY: CGFloat, dropSize: CGFloat, delay: Double, startPoint: CGPoint) {
        self.char = char
        self.targetX = targetX
        self.targetY = targetY
        self.dropSize = dropSize
        self.delay = delay
        self.startPoint = startPoint
        self._position = State(initialValue: startPoint)
    }
    
    var body: some View {
        ZStack {
            // Drop (Visible while falling)
            if !isSplashed {
                DropShape()
                    .fill(Color.black)
                    .frame(width: dropSize, height: dropSize * 1.5) // Slightly elongated
                    .position(position)
                    .scaleEffect(dropScale)
            } else {
                // Splash Effect (Ring)
                Circle()
                    .stroke(Color.black, lineWidth: 3)
                    .frame(width: dropSize, height: dropSize)
                    .scaleEffect(splashScale)
                    .opacity(splashOpacity)
                    .position(x: targetX, y: targetY)
                
                // Letter
                Text(char)
                    .font(.system(size: 60, weight: .black, design: .rounded)) // "Proxima Nova Black" proxy
                    .foregroundStyle(Color.black)
                    .position(x: targetX, y: targetY)
                    .scaleEffect(letterScale)
            }
        }
        .task {
             // Fall animation
             try? await Task.sleep(for: .seconds(delay))
             withAnimation(.easeIn(duration: 0.6)) {
                 position = CGPoint(x: targetX, y: targetY)
             }
             
             // Impact
             try? await Task.sleep(for: .seconds(0.6))
             isSplashed = true
             
             // Splash ring expansion
             withAnimation(.easeOut(duration: 0.4)) {
                 splashScale = 2.5
                 splashOpacity = 0
             }
             
             // Letter popup
             withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                 letterScale = 1.0
             }
        }
    }
}

struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Teardrop shape suitable for falling oil
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
