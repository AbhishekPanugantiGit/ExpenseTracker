import Foundation
import SwiftData

enum BudgetGroup: String, CaseIterable, Identifiable {
    case bills = "Bills"
    case expenses = "Expenses"
    case savings = "Savings"
    case debt = "Debt"

    var id: String { rawValue }
    var tint: String {
        switch self {
        case .bills: "#B8D5E8"
        case .expenses: "#D9C5EB"
        case .savings: "#EBC2D9"
        case .debt: "#F1D9A7"
        }
    }
    var symbol: String {
        switch self {
        case .bills: "house.fill"
        case .expenses: "cart.fill"
        case .savings: "sparkles"
        case .debt: "creditcard.fill"
        }
    }
}

@Model
final class BudgetItem {
    var id: UUID = UUID()
    var name: String
    var groupName: String
    var budget: Double
    var actual: Double
    var isIncluded: Bool
    var sortOrder: Int
    // Keep a declaration-level default so SwiftData can migrate existing
    // BudgetItem rows created before the year field was added.
    var year: Int = Calendar.current.component(.year, from: .now)
    var month: Int = Calendar.current.component(.month, from: .now)
    var isRecurring: Bool = false

    init(name: String, group: BudgetGroup, budget: Double, actual: Double = 0, isIncluded: Bool = true, sortOrder: Int = 0, year: Int = Calendar.current.component(.year, from: .now), month: Int = Calendar.current.component(.month, from: .now), isRecurring: Bool = false) {
        self.name = name
        self.groupName = group.rawValue
        self.budget = budget
        self.actual = actual
        self.isIncluded = isIncluded
        self.sortOrder = sortOrder
        self.year = year
        self.month = month
        self.isRecurring = isRecurring
    }

    var group: BudgetGroup { BudgetGroup(rawValue: groupName) ?? .expenses }
}

@Model
final class ExpenseTransaction {
    var id: UUID = UUID()
    var categoryID: UUID
    var categoryName: String
    var groupName: String
    var amount: Double
    var date: Date
    var note: String
    var monthKey: String
    var isSample: Bool = false

    init(categoryID: UUID, categoryName: String, group: BudgetGroup, amount: Double, date: Date, note: String, monthKey: String, isSample: Bool = false) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.groupName = group.rawValue
        self.amount = amount
        self.date = date
        self.note = note
        self.monthKey = monthKey
        self.isSample = isSample
    }
    var group: BudgetGroup { BudgetGroup(rawValue: groupName) ?? .expenses }
}

@Model
final class MonthlyPlan {
    var monthKey: String
    var income: Double
    var hasInitializedBudget: Bool = false
    var hasSampleTransactions: Bool = false
    init(monthKey: String, income: Double, hasInitializedBudget: Bool = false, hasSampleTransactions: Bool = false) {
        self.monthKey = monthKey
        self.income = income
        self.hasInitializedBudget = hasInitializedBudget
        self.hasSampleTransactions = hasSampleTransactions
    }
}

enum BudgetSeed {
    static func loadIfNeeded(context: ModelContext, items: [BudgetItem], plans: [MonthlyPlan], year: Int, month: Int) {
        let storedItems = (try? context.fetch(FetchDescriptor<BudgetItem>())) ?? items
        let storedPlans = (try? context.fetch(FetchDescriptor<MonthlyPlan>())) ?? plans
        let key = Self.monthKey(for: year, month: month)
        let plan = storedPlans.first(where: { $0.monthKey == key })
        let rows: [(String, BudgetGroup, Double, Bool)] = [
            ("Rent", .bills, 28000, true), ("Council Tax", .bills, 2000, true), ("Electricity", .bills, 1100, true),
            ("Water", .bills, 800, true), ("Broadband", .bills, 400, true), ("Subscriptions", .bills, 200, true),
            ("Groceries & Takeaways", .expenses, 9000, false), ("Shopping & Clothes", .expenses, 7000, false),
            ("Dining Out", .expenses, 3000, false), ("Transport & Fuel", .expenses, 4000, false),
            ("Health & Medical", .expenses, 2500, false), ("Household Items", .expenses, 2500, false),
            ("Gym, Self-Care & Haircuts", .expenses, 4000, false), ("Petrol & Weekend Trip", .expenses, 6000, false),
            ("Investments", .savings, 15000, true), ("Retirement", .savings, 10000, true), ("Holiday", .savings, 7500, false),
            ("Car Payment", .debt, 5500, true), ("Business Loan", .debt, 4000, true), ("Credit Cards", .debt, 3500, true),
            ("Personal Loan", .debt, 3000, true), ("Student Loan", .debt, 2000, true)
        ]
        var periodItems = storedItems.filter { $0.year == year && $0.month == month }
        for (index, row) in rows.enumerated() {
            let existing = periodItems.first { $0.group == row.1 && $0.name.localizedCaseInsensitiveCompare(row.0) == .orderedSame }
            if existing == nil {
                let seeded = BudgetItem(name: row.0, group: row.1, budget: row.2, actual: 0, sortOrder: index, year: year, month: month, isRecurring: row.3)
                context.insert(seeded)
                periodItems.append(seeded)
            }
        }
        if let previous = previousPeriod(year: year, month: month) {
            let priorRecurring = storedItems.filter { $0.year == previous.year && $0.month == previous.month && $0.isRecurring }
            for (offset, item) in priorRecurring.enumerated() {
                if let existing = periodItems.first(where: { $0.group == item.group && $0.name.localizedCaseInsensitiveCompare(item.name) == .orderedSame }) {
                    existing.budget = item.budget
                    existing.isIncluded = item.isIncluded
                    existing.isRecurring = true
                } else {
                    let recurring = BudgetItem(name: item.name, group: item.group, budget: item.budget, actual: 0, isIncluded: item.isIncluded, sortOrder: rows.count + offset, year: year, month: month, isRecurring: true)
                    context.insert(recurring)
                    periodItems.append(recurring)
                }
            }
        }
        if let plan {
            plan.hasInitializedBudget = true
        } else {
            context.insert(MonthlyPlan(monthKey: key, income: 145000, hasInitializedBudget: true))
        }
        do {
            try context.save()
        } catch {
            print("Expense Tracker: could not save the monthly budget seed: \(error.localizedDescription)")
        }
    }

    static func monthKey(for year: Int, month: Int) -> String {
        return String(format: "%04d-%02d", year, month)
    }

    static func previousPeriod(year: Int, month: Int) -> (year: Int, month: Int)? {
        var parts = DateComponents(); parts.year = year; parts.month = month; parts.day = 1
        guard let date = Calendar.current.date(from: parts), let previous = Calendar.current.date(byAdding: .month, value: -1, to: date) else { return nil }
        return (Calendar.current.component(.year, from: previous), Calendar.current.component(.month, from: previous))
    }

    static func copyBudget(from source: [BudgetItem], year: Int, month: Int, into items: [BudgetItem], plans: [MonthlyPlan], context: ModelContext) {
        let targetItems = items.filter { $0.year == year && $0.month == month }
        for prior in source {
            if let existing = targetItems.first(where: { $0.group == prior.group && $0.name.localizedCaseInsensitiveCompare(prior.name) == .orderedSame }) {
                existing.budget = prior.budget
                existing.isIncluded = prior.isIncluded
                existing.isRecurring = prior.isRecurring
            } else {
                context.insert(BudgetItem(name: prior.name, group: prior.group, budget: prior.budget, actual: 0, isIncluded: prior.isIncluded, sortOrder: prior.sortOrder, year: year, month: month, isRecurring: prior.isRecurring))
            }
        }
        if let previous = previousPeriod(year: year, month: month),
           let sourcePlan = plans.first(where: { $0.monthKey == monthKey(for: previous.year, month: previous.month) }) {
            let targetKey = monthKey(for: year, month: month)
            if let targetPlan = plans.first(where: { $0.monthKey == targetKey }) {
                targetPlan.income = sourcePlan.income
            } else {
                context.insert(MonthlyPlan(monthKey: targetKey, income: sourcePlan.income))
            }
        }
        do {
            try context.save()
        } catch {
            print("Expense Tracker: could not copy the monthly budget: \(error.localizedDescription)")
        }
    }

    static func seedSampleTransactionsIfNeeded(context: ModelContext, year: Int, month: Int) {
        let key = monthKey(for: year, month: month)
        guard let plan = ((try? context.fetch(FetchDescriptor<MonthlyPlan>())) ?? []).first(where: { $0.monthKey == key }) else { return }
        let transactions = (try? context.fetch(FetchDescriptor<ExpenseTransaction>())) ?? []
        if transactions.contains(where: { $0.isSample && $0.monthKey == key }) {
            plan.hasSampleTransactions = true
            do { try context.save() } catch { print("Expense Tracker: could not save sample transaction state: \(error.localizedDescription)") }
            return
        }
        // Keep the demo set in one month only. Do not mark another month as seeded
        // just because demo transactions already exist elsewhere.
        if transactions.contains(where: \.isSample) { return }
        guard !plan.hasSampleTransactions else { return }
        guard !transactions.contains(where: { $0.monthKey == key }) else {
            plan.hasSampleTransactions = true
            do { try context.save() } catch { print("Expense Tracker: could not save sample transaction state: \(error.localizedDescription)") }
            return
        }
        plan.hasSampleTransactions = false
        let items = (try? context.fetch(FetchDescriptor<BudgetItem>())) ?? []
        let periodItems = items.filter { $0.year == year && $0.month == month }
        guard !periodItems.contains(where: { $0.actual > 0 }) else {
            plan.hasSampleTransactions = true
            do { try context.save() } catch { print("Expense Tracker: could not save sample transaction state: \(error.localizedDescription)") }
            return
        }
        let examples: [(String, Double, Int, String)] = [
            ("Rent", 28000, 2, "Monthly rent"),
            ("Electricity", 950, 5, "Electricity bill"),
            ("Groceries & Takeaways", 6250, 10, "Groceries"),
            ("Dining Out", 1450, 14, "Dinner out"),
            ("Transport & Fuel", 2200, 18, "Fuel"),
            ("Credit Cards", 3500, 22, "Card payment")
        ]
        for example in examples {
            guard let item = periodItems.first(where: { $0.name == example.0 }) else { continue }
            var parts = DateComponents(); parts.year = year; parts.month = month; parts.day = example.2
            let date = Calendar.current.date(from: parts) ?? .now
            item.actual += example.1
            context.insert(ExpenseTransaction(categoryID: item.id, categoryName: item.name, group: item.group, amount: example.1, date: date, note: example.3, monthKey: key, isSample: true))
        }
        plan.hasSampleTransactions = true
        do {
            try context.save()
        } catch {
            print("Expense Tracker: could not save sample transactions: \(error.localizedDescription)")
        }
    }
}
