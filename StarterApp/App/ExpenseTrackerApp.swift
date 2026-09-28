import SwiftUI

@main
struct ExpenseTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [BudgetItem.self, MonthlyPlan.self, ExpenseTransaction.self])
    }
}
