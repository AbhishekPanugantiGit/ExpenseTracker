import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Overview", systemImage: "house.fill") {
                DashboardView()
            }
            Tab("Plan", systemImage: "list.bullet.rectangle.portrait") {
                BudgetPlanView()
            }
            Tab("Activity", systemImage: "creditcard") {
                ActivityView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
