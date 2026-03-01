import SwiftUI
import Charts

struct StepBar: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let steps: Double
}

struct StepsView: View {
    @Environment(HealthViewModel.self) var vm
    @State private var selectedDate: Date? = nil   // raw value from chartXSelection — fires constantly
    @State private var displayedBar: StepBar? = nil // only updates when finger crosses into a new bar
    @State private var showSettings = false

    // MARK: - Computed data

    var chartData: [StepBar] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return vm.weeklySteps
            .sorted { $0.key < $1.key }
            .map { StepBar(label: formatter.string(from: $0.key), date: $0.key, steps: $0.value) }
    }

    var weeklyTotal: Int {
        Int(vm.weeklySteps.values.reduce(0, +))
    }

    var dailyAverage: Int {
        let nonZero = vm.weeklySteps.values.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return Int(nonZero.reduce(0, +) / Double(nonZero.count))
    }

    var bestDay: StepBar? {
        chartData.max(by: { $0.steps < $1.steps })
    }

    var daysHitGoal: Int {
        chartData.filter { $0.steps >= Double(vm.dailyStepGoal) }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsRow
                    chartSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Steps")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Text("Daily goal")
                                Spacer()
                                Text(vm.dailyStepGoal.formatted() + " steps")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(vm.dailyStepGoal) },
                                    set: { vm.dailyStepGoal = (Int($0) / 500) * 500 }
                                ),
                                in: 1000...30000,
                                step: 500
                            )
                            .tint(.blue)
                            HStack {
                                Text("1,000")
                                Spacer()
                                Text("30,000")
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        } header: {
                            Text("Step Goal")
                        }
                    }
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StepStatCard(label: "This Week",  value: weeklyTotal.formatted(),          subtitle: "total steps")
            StepStatCard(label: "Daily Avg",  value: dailyAverage.formatted(),         subtitle: "steps / day")
            if let best = bestDay {
                StepStatCard(label: "Best Day", value: Int(best.steps).formatted(), subtitle: best.label)
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Fixed two-line header — height never changes, so the chart never shifts
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 Days")
                    .font(.headline)
                Text("\(daysHitGoal)/7")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(daysHitGoal == 7 ? Color.orange : Color.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        (daysHitGoal == 7 ? Color.orange : Color.blue).opacity(0.12),
                        in: Capsule()
                    )
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: daysHitGoal)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    // Line 1: step count — invisible when nothing is selected
                    Text(displayedBar.map { Int($0.steps).formatted() + " steps" } ?? " ")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.blue)
                        .opacity(displayedBar != nil ? 1 : 0)
                    // Line 2: date or hint
                    Text(displayedBar.map {
                        $0.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                    } ?? "Tap a bar to inspect")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                // Bars
                ForEach(chartData) { bar in
                    let isToday    = Calendar.current.isDateInToday(bar.date)
                    let isSelected = displayedBar?.id == bar.id

                    BarMark(
                        x: .value("Day", bar.date, unit: .day),
                        y: .value("Steps", bar.steps),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(
                        (isToday || isSelected)
                            ? Color.blue.gradient
                            : Color.blue.opacity(0.3).gradient
                    )
                    .cornerRadius(7)
                }

                // Daily goal line
                RuleMark(y: .value("Goal", vm.dailyStepGoal))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .top, alignment: .trailing, spacing: 3) {
                        Text("Goal")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let isToday = Calendar.current.isDateInToday(date)
                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(.caption2.weight(isToday ? .bold : .regular))
                                .foregroundStyle(isToday ? Color.blue : Color.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let steps = value.as(Double.self) {
                            Text(steps >= 1000 ? "\(Int(steps / 1000))k" : "\(Int(steps))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedDate)
            // Only update displayedBar when the finger moves into a different bar,
            // not on every pixel — this eliminates the chart re-render storm.
            .onChange(of: selectedDate) { _, newDate in
                guard let newDate else {
                    displayedBar = nil
                    return
                }
                let nearest = chartData.min(by: {
                    abs($0.date.timeIntervalSince(newDate)) < abs($1.date.timeIntervalSince(newDate))
                })
                if nearest?.id != displayedBar?.id {
                    displayedBar = nearest
                }
            }
            .frame(height: 210)

            if daysHitGoal == 7 {
                Label("Perfect week — goal hit every day!", systemImage: "star.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

}

// MARK: - Stat Card

private struct StepStatCard: View {
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)

            Text(value)
                .font(.title3.bold().monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
