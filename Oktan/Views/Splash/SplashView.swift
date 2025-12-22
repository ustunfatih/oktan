import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack {
            Image(systemName: "drop.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text("Oktan")
                .font(.largeTitle.bold())

            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    SplashView()
}
