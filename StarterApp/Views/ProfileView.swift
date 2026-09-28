import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text("Alex Rivera")
                    .font(.title.bold())

                Text("Learning SwiftUI")
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ProfileRow(label: "Email", value: "alex@example.com")
                    ProfileRow(label: "City", value: "Austin")
                    ProfileRow(label: "Joined", value: "September 2026")
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Profile")
        }
    }
}

private struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    ProfileView()
}
