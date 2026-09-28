import SwiftUI

struct ExploreView: View {
    private let places = [
        ("Golden Gate", "San Francisco", "bridge.fill"),
        ("Central Park", "New York", "leaf.fill"),
        ("Pike Place", "Seattle", "cart.fill"),
        ("Navy Pier", "Chicago", "ferry.fill")
    ]

    var body: some View {
        NavigationStack {
            List(places, id: \.0) { place in
                HStack(spacing: 12) {
                    Image(systemName: place.2)
                        .frame(width: 32)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading) {
                        Text(place.0)
                            .font(.headline)
                        Text(place.1)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Explore")
        }
    }
}

#Preview {
    ExploreView()
}
