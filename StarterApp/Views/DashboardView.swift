import SwiftUI
import SwiftData
import Charts

private enum Palette {
    static let ink = Color(red: 0.16, green: 0.17, blue: 0.20)
    static let muted = Color(red: 0.48, green: 0.49, blue: 0.52)
    static let canvas = Color(red: 0.975, green: 0.965, blue: 0.955)
    static let peach = Color(red: 0.91, green: 0.69, blue: 0.60)
    static let colors: [Color] = [Color(red: 0.64, green: 0.82, blue: 0.79), Color(red: 0.65, green: 0.79, blue: 0.90), Color(red: 0.79, green: 0.69, blue: 0.89), Color(red: 0.91, green: 0.68, blue: 0.82)]
}

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BudgetItem.sortOrder) private var items: [BudgetItem]
    @Query private var plans: [MonthlyPlan]
    @AppStorage("selectedBudgetYear") private var selectedYear = Calendar.current.component(.year, from: .now)
    @AppStorage("selectedBudgetMonth") private var selectedMonth = Calendar.current.component(.month, from: .now)
    @AppStorage("currencyCode") private var currencyCode = "INR"
    @State private var showingPayment = false
    @State private var showingIncomeEditor = false
    @State private var selectedGroup: BudgetGroup?

    private var periodItems: [BudgetItem] { items.filter { $0.year == selectedYear && $0.month == selectedMonth } }
    private var plan: MonthlyPlan? { plans.first(where: { $0.monthKey == BudgetSeed.monthKey(for: selectedYear, month: selectedMonth) }) }
    private var income: Double { plan?.income ?? 0 }
    private var planned: Double { periodItems.filter(\.isIncluded).reduce(0) { $0 + $1.budget } }
    private var spent: Double { periodItems.filter(\.isIncluded).reduce(0) { $0 + $1.actual } }
    private var remaining: Double { income - planned }
    private var monthTitle: String {
        var parts = DateComponents(); parts.year = selectedYear; parts.month = selectedMonth; parts.day = 1
        return (Calendar.current.date(from: parts) ?? .now).formatted(.dateTime.month(.wide)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    remainingCard
                    cashFlowCard
                    allocationCard
                    ForEach(BudgetGroup.allCases) { group in
                        groupCard(group)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPayment) { LogPaymentView(year: selectedYear, month: selectedMonth) }
            .sheet(isPresented: $showingIncomeEditor) { EditMonthlyIncomeView(year: selectedYear, month: selectedMonth, income: income) }
            .sheet(item: $selectedGroup) { group in GroupDetailView(group: group, year: selectedYear, month: selectedMonth) }
            .task {
                BudgetSeed.loadIfNeeded(context: context, items: items, plans: plans, year: selectedYear, month: selectedMonth)
                BudgetSeed.seedSampleTransactionsIfNeeded(context: context, year: selectedYear, month: selectedMonth)
            }
            .onChange(of: selectedYear) { _, year in
                BudgetSeed.loadIfNeeded(context: context, items: items, plans: plans, year: year, month: selectedMonth)
                BudgetSeed.seedSampleTransactionsIfNeeded(context: context, year: year, month: selectedMonth)
            }
            .onChange(of: selectedMonth) { _, month in
                BudgetSeed.loadIfNeeded(context: context, items: items, plans: plans, year: selectedYear, month: month)
                BudgetSeed.seedSampleTransactionsIfNeeded(context: context, year: selectedYear, month: month)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(monthTitle).font(.system(size: 27, weight: .bold, design: .rounded)).tracking(3)
                Text("MONTHLY MONEY PLAN").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                
                Picker("Year", selection: $selectedYear) {
                    ForEach((Calendar.current.component(.year, from: .now) - 5)...(Calendar.current.component(.year, from: .now) + 1), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                
                Picker("Month", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(DateFormatter().monthSymbols[month - 1]).tag(month)
                    }
                }

            }
            .pickerStyle(.menu)
            Button { showingPayment = true } label: {
                Label("Log", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Palette.ink, in: Capsule())
            }
            .accessibilityLabel("Log payment")
        }
        .foregroundStyle(Palette.ink)
        .padding(.bottom, 2)
    }

    private var remainingCard: some View {
        VStack(spacing: 10) {
            Text("AMOUNT LEFT TO SPEND").font(.system(size: 11, weight: .bold)).tracking(2.3).foregroundStyle(Palette.ink)
            ZStack {
                Chart {
                    SectorMark(angle: .value("Allocated", max(min(planned, max(income, 1)), 0)), innerRadius: .ratio(0.76), angularInset: 1)
                        .foregroundStyle(Palette.peach)
                    SectorMark(angle: .value("Remaining", max(remaining, 0.01)), innerRadius: .ratio(0.76), angularInset: 1)
                        .foregroundStyle(Palette.peach.opacity(0.27))
                }
                .chartLegend(.hidden)
                VStack(spacing: 2) {
                    Text(remaining, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.system(size: 29, weight: .medium, design: .rounded)).minimumScaleFactor(0.7).lineLimit(1)
                    Text("of \(income, format: .currency(code: currencyCode).precision(.fractionLength(0))) income")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
                }
            }
            .frame(height: 188)
            HStack {
                Label("Income", systemImage: "arrow.down.left").foregroundStyle(Palette.muted)
                Spacer()
                Text(income, format: .currency(code: currencyCode)).fontWeight(.semibold)
                Button("Edit") { showingIncomeEditor = true }
                    .font(.system(size: 12, weight: .semibold))
            }
            .font(.system(size: 13))
            .padding(.top, 5)
        }
        .padding(18)
        .cardStyle()
    }

    private var cashFlowCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeading(title: "CASH FLOW SUMMARY", subtitle: "Budget compared with actual")
            Chart {
                ForEach(BudgetGroup.allCases) { group in
                    BarMark(x: .value("Amount", groupBudget(group)), y: .value("Group", group.rawValue), height: .ratio(0.34))
                        .foregroundStyle(Palette.colors[BudgetGroup.allCases.firstIndex(of: group)!].opacity(0.65)).position(by: .value("Type", "Budget"))
                    BarMark(x: .value("Amount", groupActual(group)), y: .value("Group", group.rawValue), height: .ratio(0.34))
                        .foregroundStyle(Palette.colors[BudgetGroup.allCases.firstIndex(of: group)!]).position(by: .value("Type", "Actual"))
                }
            }
            .chartLegend(position: .top, alignment: .trailing)
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisValueLabel(anchor: .center) {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .frame(height: 185)
        }
        .padding(18).cardStyle()
    }

    private var allocationCard: some View {
        VStack(spacing: 12) {
            SectionHeading(title: "ALLOCATION SUMMARY", subtitle: "Where your income is assigned")
            Chart {
                ForEach(BudgetGroup.allCases) { group in
                    SectorMark(angle: .value(group.rawValue, groupBudget(group)), innerRadius: .ratio(0.58), angularInset: 2)
                        .foregroundStyle(Palette.colors[BudgetGroup.allCases.firstIndex(of: group)!])
                }
            }
            .chartLegend(position: .bottom, spacing: 12)
            .frame(height: 225)
            HStack {
                Text("Budgeted").foregroundStyle(Palette.muted)
                Spacer()
                Text(planned, format: .currency(code: currencyCode)).fontWeight(.semibold)
                Text("of \(income, format: .currency(code: currencyCode))").foregroundStyle(Palette.muted)
            }.font(.system(size: 12))
        }
        .padding(18).cardStyle()
    }

    private func groupCard(_ group: BudgetGroup) -> some View {
        let rows = periodItems.filter { $0.group == group }
        return VStack(spacing: 0) {
            Button { selectedGroup = group } label: {
                HStack(spacing: 12) {
                    Image(systemName: group.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                        .frame(width: 34, height: 34).background(Color(hex: group.tint).opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.rawValue.uppercased()).font(.system(size: 12, weight: .bold)).tracking(1.5).foregroundStyle(Palette.ink)
                        Text("\(rows.count) categories").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(groupActual(group), format: .currency(code: currencyCode)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text("of \(groupBudget(group), format: .currency(code: currencyCode))").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
                }
                .padding(14)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            Rectangle().fill(Palette.ink.opacity(0.07)).frame(height: 1).padding(.horizontal, 14)
            ForEach(rows.prefix(3)) { item in
                HStack {
                    Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Text(item.actual, format: .currency(code: currencyCode)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .cardStyle()
    }

    private func groupBudget(_ group: BudgetGroup) -> Double { periodItems.filter { $0.group == group && $0.isIncluded }.reduce(0) { $0 + $1.budget } }
    private func groupActual(_ group: BudgetGroup) -> Double { periodItems.filter { $0.group == group && $0.isIncluded }.reduce(0) { $0 + $1.actual } }
}

struct GroupDetailView: View {
    let group: BudgetGroup
    let year: Int
    let month: Int
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BudgetItem.sortOrder) private var allItems: [BudgetItem]
    @AppStorage("currencyCode") private var currencyCode = "INR"
    @State private var showingAdd = false
    @State private var saveError = ""
    @State private var showingSaveError = false
    private var items: [BudgetItem] { allItems.filter { $0.group == group && $0.year == year && $0.month == month } }
    private var totalBudget: Double { items.filter(\.isIncluded).reduce(0) { $0 + $1.budget } }
    private var totalActual: Double { items.filter(\.isIncluded).reduce(0) { $0 + $1.actual } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack { Text("Category"); Spacer(); Text("Budget").frame(width: 70); Text("Actual").frame(width: 70) }
                        .font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Palette.muted)
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Button { item.isIncluded.toggle() } label: {
                                Image(systemName: item.isIncluded ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 21, weight: .medium))
                                    .foregroundStyle(item.isIncluded ? Palette.peach : Palette.peach.opacity(0.72))
                                    .frame(width: 34, height: 34, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isIncluded ? "Exclude \(item.name)" : "Include \(item.name)")
                            TextField("Category", text: Binding(get: { item.name }, set: { item.name = $0 })).font(.system(size: 13, weight: .medium))
                            Button { item.isRecurring.toggle() } label: {
                                Image(systemName: "repeat")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(item.isRecurring ? Palette.peach : Palette.muted.opacity(0.45))
                                    .frame(width: 22, height: 30)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isRecurring ? "Stop repeating monthly" : "Repeat monthly")
                            MoneyField(value: Binding(get: { item.budget }, set: { item.budget = $0 }), width: 70)
                            MoneyField(value: Binding(get: { item.actual }, set: { item.actual = $0 }), width: 70)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                    }
                    HStack {
                        Text("TOTAL").font(.system(size: 11, weight: .bold)).tracking(1)
                        Spacer()
                        Text(totalBudget, format: .currency(code: currencyCode)).font(.system(size: 11, weight: .semibold)).frame(width: 70)
                        Text(totalActual, format: .currency(code: currencyCode)).font(.system(size: 11, weight: .semibold)).frame(width: 70)
                    }.listRowBackground(Color(hex: group.tint).opacity(0.34))
                } header: {
                    Text("BUDGET  ·  ACTUAL").font(.system(size: 10, weight: .bold)).tracking(1.4)
                }
                Section {
                    Text("Tap a number to edit it. Use the checkboxes to include or exclude categories from your totals.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
            .scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle(group.rawValue).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { saveChanges() }
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .alert("Couldn’t save changes", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError)
            }
            .sheet(isPresented: $showingAdd) { AddBudgetItemView(initialGroup: group, year: year, month: month) }
        }
    }

    private func saveChanges() {
        do {
            try context.save()
        } catch {
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}

private struct EditMonthlyIncomeView: View {
    let year: Int
    let month: Int
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode = "INR"
    @State private var incomeText: String
    @State private var saveError = ""
    @State private var showingSaveError = false

    init(year: Int, month: Int, income: Double) {
        self.year = year
        self.month = month
        _incomeText = State(initialValue: Self.formattedIncome(income))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("MONTHLY INCOME · \(currencyCode)") {
                    TextField("Income amount", text: $incomeText)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Text("This income amount will be saved for \(DateFormatter().monthSymbols[month - 1]) \(year).")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveIncome() }
                }
            }
            .alert("Couldn’t save income", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError)
            }
        }
        .presentationDetents([.medium])
    }

    private func saveIncome() {
        let normalized = incomeText.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard let amount = Double(normalized), amount.isFinite, amount >= 0 else {
            saveError = "Enter a valid income amount, such as 85000 or 85000.50."
            showingSaveError = true
            return
        }
        let key = BudgetSeed.monthKey(for: year, month: month)
        do {
            let matchingPlans = try context.fetch(FetchDescriptor<MonthlyPlan>()).filter { $0.monthKey == key }
            if matchingPlans.isEmpty {
                context.insert(MonthlyPlan(monthKey: key, income: amount, hasInitializedBudget: true))
            } else {
                matchingPlans.forEach { $0.income = amount }
            }
            try context.save()
            dismiss()
        } catch {
            saveError = "Income was not saved: \(error.localizedDescription)"
            showingSaveError = true
        }
    }

    private static func formattedIncome(_ amount: Double) -> String {
        guard amount != 0 else { return "" }
        return amount.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct LogPaymentView: View {
    let year: Int
    let month: Int
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BudgetItem.sortOrder) private var allItems: [BudgetItem]
    @AppStorage("currencyCode") private var currencyCode = "INR"
    @State private var amountText = ""
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var note = ""
    @State private var saveError = ""
    @State private var showingSaveError = false

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
        _date = State(initialValue: Self.initialDate(year: year, month: month))
    }

    private var categories: [BudgetItem] { allItems.filter { $0.year == year && $0.month == month && $0.isIncluded } }
    private var periodStart: Date { Self.firstDay(year: year, month: month) }
    private var periodEnd: Date {
        (Calendar.current.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart).addingTimeInterval(-1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("PAYMENT · \(currencyCode)") {
                    TextField("Amount paid", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $categoryID) {
                        Text("Choose a category").tag(Optional<UUID>.none)
                        ForEach(categories) { item in
                            Text("\(item.group.rawValue) · \(item.name)").tag(Optional(item.id))
                        }
                    }
                    DatePicker("Date", selection: $date, in: periodStart...periodEnd, displayedComponents: .date)
                }
                Section("DETAILS") {
                    TextField("Note or merchant (optional)", text: $note)
                }
                Section {
                    Text("This payment will be added to the category’s actual amount and saved in your monthly history.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePayment() }
                        .disabled(categoryID == nil || categories.isEmpty)
                }
            }
            .alert("Couldn’t save payment", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError)
            }
            .onAppear {
                if categoryID == nil { categoryID = categories.first(where: { $0.group == .expenses })?.id ?? categories.first?.id }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func savePayment() {
        let normalized = amountText.filter { $0.isNumber || $0 == "." }
        guard let amount = Double(normalized), amount.isFinite, amount > 0 else {
            saveError = "Enter a valid payment amount greater than zero."
            showingSaveError = true
            return
        }
        guard let item = categories.first(where: { $0.id == categoryID }) else { return }
        item.actual += amount
        let transaction = ExpenseTransaction(
            categoryID: item.id,
            categoryName: item.name,
            group: item.group,
            amount: amount,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            monthKey: BudgetSeed.monthKey(for: year, month: month)
        )
        context.insert(transaction)
        do {
            try context.save()
            dismiss()
        } catch {
            item.actual -= amount
            context.delete(transaction)
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }

    private static func initialDate(year: Int, month: Int) -> Date {
        if year == Calendar.current.component(.year, from: .now), month == Calendar.current.component(.month, from: .now) {
            return .now
        }
        return firstDay(year: year, month: month)
    }

    private static func firstDay(year: Int, month: Int) -> Date {
        var parts = DateComponents(); parts.year = year; parts.month = month; parts.day = 1
        return Calendar.current.date(from: parts) ?? .now
    }
}

struct BudgetPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BudgetItem.sortOrder) private var items: [BudgetItem]
    @Query private var plans: [MonthlyPlan]
    @AppStorage("selectedBudgetYear") private var selectedYear = Calendar.current.component(.year, from: .now)
    @AppStorage("selectedBudgetMonth") private var selectedMonth = Calendar.current.component(.month, from: .now)
    @AppStorage("currencyCode") private var currencyCode = "INR"
    @State private var selectedGroup: BudgetGroup?
    @State private var showingAdd = false
    @State private var showingIncomeEditor = false
    @State private var showingCopyAlert = false
    @State private var copyAlertMessage = ""

    private var periodItems: [BudgetItem] { items.filter { $0.year == selectedYear && $0.month == selectedMonth } }
    private var monthlyPlan: MonthlyPlan? { plans.first(where: { $0.monthKey == BudgetSeed.monthKey(for: selectedYear, month: selectedMonth) }) }
    private var totalBudget: Double { periodItems.filter(\.isIncluded).reduce(0) { $0 + $1.budget } }
    private var totalActual: Double { periodItems.filter(\.isIncluded).reduce(0) { $0 + $1.actual } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MONTHLY INCOME").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Palette.muted)
                            Text(monthlyPlan?.income ?? 0, format: .currency(code: currencyCode))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                        }
                        Spacer()
                        Button("Edit") { showingIncomeEditor = true }
                            .font(.system(size: 13, weight: .semibold))
                    }.padding(.vertical, 6)
                }
                Section {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in Text(DateFormatter().monthSymbols[month - 1]).tag(month) }
                    }
                    Picker("Year", selection: $selectedYear) {
                        ForEach((Calendar.current.component(.year, from: .now) - 5)...(Calendar.current.component(.year, from: .now) + 1), id: \.self) { year in Text(String(year)).tag(year) }
                    }
                }
                Section {
                    Button {
                        copyPreviousMonthBudget()
                    } label: {
                        Label("Copy previous month’s budget", systemImage: "doc.on.doc")
                    }
                } footer: {
                    Text("Copies budget amounts and categories. Actual spending remains unchanged.")
                }
                Section("YOUR BUDGET") {
                    ForEach(BudgetGroup.allCases) { group in
                        let rows = periodItems.filter { $0.group == group && $0.isIncluded }
                        Button { selectedGroup = group } label: {
                            HStack(spacing: 12) {
                                Image(systemName: group.symbol).foregroundStyle(Palette.ink)
                                    .frame(width: 34, height: 34).background(Color(hex: group.tint).opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(group.rawValue).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                    Text("\(rows.count) active categories").font(.system(size: 11)).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(rows.reduce(0) { $0 + $1.actual }, format: .currency(code: currencyCode)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                                    Text("budget \(rows.reduce(0) { $0 + $1.budget }, format: .currency(code: currencyCode))").font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                Section {
                    HStack { Text("Budgeted"); Spacer(); Text(totalBudget, format: .currency(code: currencyCode)).fontWeight(.semibold) }
                    HStack { Text("Actual"); Spacer(); Text(totalActual, format: .currency(code: currencyCode)).fontWeight(.semibold) }
                    HStack { Text("Left to spend"); Spacer(); Text((monthlyPlan?.income ?? 0) - totalActual, format: .currency(code: currencyCode)).fontWeight(.bold).foregroundStyle(Palette.peach) }
                } header: { Text("MONTHLY TOTALS") }
            }
            .scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle("Budget plan")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(item: $selectedGroup) { GroupDetailView(group: $0, year: selectedYear, month: selectedMonth) }
            .sheet(isPresented: $showingAdd) { AddBudgetItemView(year: selectedYear, month: selectedMonth) }
            .sheet(isPresented: $showingIncomeEditor) { EditMonthlyIncomeView(year: selectedYear, month: selectedMonth, income: monthlyPlan?.income ?? 0) }
            .task {
                BudgetSeed.loadIfNeeded(context: context, items: items, plans: plans, year: selectedYear, month: selectedMonth)
                BudgetSeed.seedSampleTransactionsIfNeeded(context: context, year: selectedYear, month: selectedMonth)
            }
            .onChange(of: selectedYear) { _, year in
                BudgetSeed.loadIfNeeded(context: context, items: items, plans: plans, year: year, month: selectedMonth)
                BudgetSeed.seedSampleTransactionsIfNeeded(context: context, year: year, month: selectedMonth)
            }
            .onChange(of: selectedMonth) { _, month in
                BudgetSeed.loadIfNeeded(context: context, items: items, plans: plans, year: selectedYear, month: month)
                BudgetSeed.seedSampleTransactionsIfNeeded(context: context, year: selectedYear, month: month)
            }
            .alert("Monthly budget", isPresented: $showingCopyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(copyAlertMessage)
            }
        }
    }

    private func copyPreviousMonthBudget() {
        guard let previous = BudgetSeed.previousPeriod(year: selectedYear, month: selectedMonth) else { return }
        let source = items.filter { $0.year == previous.year && $0.month == previous.month }
        guard !source.isEmpty else {
            copyAlertMessage = "There is no budget in the previous month to copy yet."
            showingCopyAlert = true
            return
        }
        BudgetSeed.copyBudget(from: source, year: selectedYear, month: selectedMonth, into: items, plans: plans, context: context)
        copyAlertMessage = "Income, budget amounts, and categories copied from \(DateFormatter().monthSymbols[previous.month - 1]) \(previous.year). Actual spending was kept as-is."
        showingCopyAlert = true
    }
}

private struct MoneyField: View {
    @Binding var value: Double
    var width: CGFloat
    @State private var text: String

    init(value: Binding<Double>, width: CGFloat) {
        _value = value
        self.width = width
        _text = State(initialValue: value.wrappedValue == 0 ? "" : value.wrappedValue.formatted(.number.precision(.fractionLength(0...2))))
    }

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .frame(width: width)
            .onChange(of: text) { _, newValue in
                let normalized = newValue.filter { $0.isNumber || $0 == "." }
                value = normalized.isEmpty ? 0 : (Double(normalized) ?? value)
            }
    }
}

private struct AddBudgetItemView: View {
    var initialGroup: BudgetGroup = .expenses
    var year: Int = Calendar.current.component(.year, from: .now)
    var month: Int = Calendar.current.component(.month, from: .now)
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var group: BudgetGroup = .expenses
    @State private var budget = 0.0
    @State private var actual = 0.0
    @State private var isRecurring = false
    @State private var saveError = ""
    @State private var showingSaveError = false
    @Query(sort: \BudgetItem.sortOrder) private var items: [BudgetItem]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $name)
                Picker("Section", selection: $group) { ForEach(BudgetGroup.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Budget", value: $budget, format: .number).keyboardType(.decimalPad)
                TextField("Actual", value: $actual, format: .number).keyboardType(.decimalPad)
                Toggle("Repeats every month", isOn: $isRecurring)
            }
            .navigationTitle("New category").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .alert("Couldn’t save category", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError)
            }
            .onAppear { group = initialGroup }
        }
        .presentationDetents([.medium])
    }
    private func save() {
        let new = BudgetItem(name: name.trimmingCharacters(in: .whitespaces), group: group, budget: budget, actual: actual, sortOrder: (items.filter { $0.year == year && $0.month == month }.map(\.sortOrder).max() ?? -1) + 1, year: year, month: month, isRecurring: isRecurring)
        context.insert(new)
        do {
            try context.save()
            dismiss()
        } catch {
            context.delete(new)
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}

private struct SectionHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(Palette.ink)
            Text(subtitle).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self.background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.ink.opacity(0.055), lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.035), radius: 12, y: 5)
    }
}

private extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(raw, radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}

#Preview {
    DashboardView().modelContainer(for: [BudgetItem.self, MonthlyPlan.self], inMemory: true)
}
