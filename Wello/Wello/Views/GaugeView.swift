import SwiftUI

/// Jauge circulaire de progression réutilisable (iOS, et plus tard Widget/Watch).
struct GaugeView: View {
    let consomméML: Int
    let objectifML: Int

    private var progression: Double {
        guard objectifML > 0 else { return 0 }
        return min(Double(consomméML) / Double(objectifML), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progression)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progression)
            VStack(spacing: 4) {
                Text("\(consomméML)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("/ \(objectifML) ml")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
        .padding()
    }
}

#Preview {
    GaugeView(consomméML: 1200, objectifML: 2500)
}
