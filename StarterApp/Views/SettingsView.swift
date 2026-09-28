import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("currencyCode") private var currencyCode = "INR"

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    Toggle("Dark mode", isOn: $darkModeEnabled)
                    Picker("Currency", selection: $currencyCode) {
                        Text("Indian Rupee (₹)").tag("INR")
                        Text("US Dollar ($)").tag("USD")
                        Text("Euro (€)").tag("EUR")
                        Text("British Pound (£)").tag("GBP")
                        Text("Canadian Dollar (CA$)").tag("CAD")
                        Text("Australian Dollar (A$)").tag("AUD")
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Expense Tracker")
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
