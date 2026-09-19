import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    Toggle("Dark mode", isOn: $darkModeEnabled)
                }

                Section("About") {
                    LabeledContent("App", value: "StarterApp")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Platform", value: "iOS 27")
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
        }
    }
}

#Preview {
    SettingsView()
}
