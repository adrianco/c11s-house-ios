import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "house.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("C11S House")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Voice-based House Consciousness")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
