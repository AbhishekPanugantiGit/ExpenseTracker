import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExpenseTransaction.date, order: .reverse) private var allTransactions: [ExpenseTransaction]
    @Query private var budgetItems: [BudgetItem]
    @AppStorage("selectedBudgetYear") private var selectedYear = Calendar.current.component(.year, from: .now)
    @AppStorage("selectedBudgetMonth") private var selectedMonth = Calendar.current.component(.month, from: .now)
    @AppStorage("currencyCode") private var currencyCode = "INR"
    @State private var showingPaymentForm = false

    private var monthKey: String { BudgetSeed.monthKey(for: selectedYear, month: selectedMonth) }
    private var transactions: [ExpenseTransaction] { allTransactions.filter { $0.monthKey == monthKey } }
    private var sampleTransaction: ExpenseTransaction? { allTransactions.first(where: \.isSample) }
    private var emptyDescription: String {
        if let sampleTransaction {
            let sampleMonth = sampleTransaction.date.formatted(.dateTime.month(.wide).year())
            return "Demo payments are in \(sampleMonth). Change the month above to view them, or tap + to add a payment here."
        }
        return "Tap + to log a payment for this month."
    }
    private var monthTitle: String {
        "\(DateFormatter().monthSymbols[selectedMonth - 1]) \(selectedYear)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in Text(DateFormatter().monthSymbols[month - 1]).tag(month) }
                    }
                    Picker("Year", selection: $selectedYear) {
                        ForEach((Calendar.current.component(.year, from: .now) - 5)...(Calendar.current.component(.year, from: .now) + 1), id: \.self) { year in Text(String(year)).tag(year) }
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PAYMENTS").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(.secondary)
                            Text(monthTitle).font(.title3.weight(.semibold))
                        }
                        Spacer()
                        Text(transactions.reduce(0) { $0 + $1.amount }, format: .currency(code: currencyCode))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .padding(.vertical, 4)
                }

                if transactions.isEmpty {
                    ContentUnavailableView("No payments yet", systemImage: "tray", description: Text(emptyDescription))
                        .listRowBackground(Color.clear)
                } else {
                    Section("HISTORY") {
                        ForEach(transactions) { transaction in
                            HStack(spacing: 12) {
                                Image(systemName: transaction.group.symbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(transaction.note.isEmpty ? transaction.categoryName : transaction.note)
                                            .font(.system(size: 14, weight: .semibold))
                                        if transaction.isSample {
                                            Text("SAMPLE").font(.system(size: 8, weight: .bold)).tracking(0.5)
                                                .foregroundStyle(.secondary).padding(.horizontal, 5).padding(.vertical, 3)
                                                .background(Color.gray.opacity(0.12), in: Capsule())
                                        }
                                    }
                                    Text("\(transaction.categoryName) · \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 6)
                                Text(transaction.amount, format: .currency(code: currencyCode))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                            .padding(.vertical, 3)
                        }
                        .onDelete(perform: deleteTransactions)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.975, green: 0.965, blue: 0.955))
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingPaymentForm = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Log payment")
                }
            }
            .sheet(isPresented: $showingPaymentForm) {
                LogPaymentView(year: selectedYear, month: selectedMonth)
            }
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = transactions[index]
            if let item = budgetItems.first(where: { $0.id == transaction.categoryID }) {
                item.actual = max(0, item.actual - transaction.amount)
            }
            context.delete(transaction)
        }
        try? context.save()
    }
}

#Preview {
    ActivityView().modelContainer(for: [BudgetItem.self, MonthlyPlan.self, ExpenseTransaction.self], inMemory: true)
}
