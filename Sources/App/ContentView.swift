import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("PhotoSwiper")
                .font(.largeTitle.bold())
            Text("Build pipeline alive ✓")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
