import SwiftUI

struct HomeView: View {
    private let tips = [
        HomeTip(
            id: "swiftui",
            title: "SwiftUI basics",
            summary: "Views, modifiers, and previews",
            detail: "Every screen is a View. Stack layouts with VStack, HStack, and ZStack, then style them with modifiers like padding and font."
        ),
        HomeTip(
            id: "navigation",
            title: "Move between pages",
            summary: "Tabs plus NavigationStack",
            detail: "The bottom tabs switch main pages. NavigationLink inside a page pushes a detail screen, like this one."
        ),
        HomeTip(
            id: "simulator",
            title: "Run in the Simulator",
            summary: "Pick an iPhone running iOS 27",
            detail: "In Xcode, choose an iPhone simulator at the top, then press Command-R. The first launch of a simulator can take a minute."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome to StarterApp")
                        .font(.largeTitle.bold())

                    Text("Four simple pages you can open in Xcode and run on iOS 27.")
                        .foregroundStyle(.secondary)

                    ForEach(tips) { tip in
                        NavigationLink(value: tip) {
                            HStack(spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                    .frame(width: 36, height: 36)
                                    .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tip.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(tip.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationDestination(for: HomeTip.self) { tip in
                TipDetailView(tip: tip)
            }
        }
    }
}

struct HomeTip: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let detail: String
}

struct TipDetailView: View {
    let tip: HomeTip

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tip.title)
                .font(.title.bold())
            Text(tip.detail)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .navigationTitle("Tip")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
}
