import SwiftUI

// MARK: - Sheet state

private enum ZoneSheet: Identifiable {
    case edit(HeartRateZone)
    case add

    var id: String {
        switch self {
        case .edit(let z): return z.id.uuidString
        case .add: return "add"
        }
    }
}

// MARK: - Zones View

struct ZonesView: View {
    @Environment(HealthViewModel.self) var vm
    @State private var activeSheet: ZoneSheet? = nil

    // MARK: - Computed metrics

    private var totalWeekMinutes: Double {
        vm.zoneMinutesThisWeek.values.reduce(0, +)
    }

    private var totalTodayMinutes: Double {
        vm.zoneMinutesToday.values.reduce(0, +)
    }

    private var zonesOnTarget: Int {
        vm.zones.filter { zone in
            guard zone.weeklyTargetMinutes > 0 else { return false }
            return vm.zoneMinutesThisWeek[zone.id, default: 0] >= Double(zone.weeklyTargetMinutes)
        }.count
    }

    private var topZone: HeartRateZone? {
        vm.zones
            .filter { vm.zoneMinutesThisWeek[$0.id, default: 0] > 0 }
            .max(by: { vm.zoneMinutesThisWeek[$0.id, default: 0] < vm.zoneMinutesThisWeek[$1.id, default: 0] })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    weeklyStatsRow
                    todayCard
                    ForEach(vm.zones) { zone in
                        ZoneProgressCard(
                            zone: zone,
                            actual: vm.zoneMinutesThisWeek[zone.id, default: 0],
                            color: bpmColor(for: zone, among: vm.zones)
                        )
                        .onTapGesture { activeSheet = .edit(zone) }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Heart Rate Zones")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .add } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await vm.refreshData() }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .edit(let zone):
                    ZoneEditSheet(
                        zone: zone,
                        isNew: false,
                        onSave: { updated in
                            var zones = vm.zones
                            if let i = zones.firstIndex(where: { $0.id == updated.id }) {
                                zones[i] = updated
                            }
                            vm.saveZones(zones)
                        },
                        onDelete: {
                            vm.saveZones(vm.zones.filter { $0.id != zone.id })
                        }
                    )
                case .add:
                    ZoneEditSheet(
                        zone: HeartRateZone(name: "", minBPM: 100, maxBPM: 140, weeklyTargetMinutes: 60),
                        isNew: true,
                        onSave: { newZone in
                            vm.saveZones(vm.zones + [newZone])
                        },
                        onDelete: {}
                    )
                }
            }
        }
    }
}

// MARK: - Zone Progress Card

private struct ZoneProgressCard: View {
    let zone: HeartRateZone
    let actual: Double
    let color: Color

    var progress: Double {
        guard zone.weeklyTargetMinutes > 0 else { return 0 }
        return min(actual / Double(zone.weeklyTargetMinutes), 1.0)
    }
    var goalMet: Bool { progress >= 1.0 }
    var remaining: Int { max(zone.weeklyTargetMinutes - Int(actual), 0) }

    var body: some View {
        HStack(spacing: 16) {

            // Circular progress ring — larger, percentage prominent
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.7), value: progress)
                VStack(spacing: -1) {
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                    Text("%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color.opacity(0.7))
                }
            }
            .frame(width: 72, height: 72)

            // Details
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(zone.name)
                        .font(.headline)
                    Spacer()
                    // Goal-met badge — pill instead of bare icon
                    if goalMet {
                        Label("Complete", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color.opacity(0.15), in: Capsule())
                    }
                }

                Text("\(zone.minBPM)–\(zone.maxBPM) BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.15))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.gradient)
                            .frame(width: geo.size.width * progress, height: 5)
                            .animation(.spring(duration: 0.7), value: progress)
                    }
                }
                .frame(height: 5)

                HStack {
                    Text("\(Int(actual)) of \(zone.weeklyTargetMinutes) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(remaining > 0 ? "\(remaining) min left" : "Goal reached!")
                        .font(.caption2.weight(goalMet ? .semibold : .regular))
                        .foregroundStyle(goalMet ? color : color.opacity(0.8))
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        // Tinted background: deeper tint when goal is met
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(goalMet ? 0.10 : 0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(goalMet ? 0.45 : 0.0), lineWidth: 1.5)
        }
        .animation(.easeInOut(duration: 0.3), value: goalMet)
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Zone Edit Sheet

private struct ZoneEditSheet: View {
    @State var zone: HeartRateZone
    let isNew: Bool
    let onSave: (HeartRateZone) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var isValid: Bool { !zone.name.isEmpty && zone.minBPM < zone.maxBPM }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Zone Name")
                        TextField("e.g. Zone 2 - Aerobic", text: $zone.name)
                            .font(.headline)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }

                    // BPM range
                    VStack(alignment: .leading, spacing: 10) {
                        fieldLabel("Heart Rate Range")
                        HStack(spacing: 12) {
                            NumberAdjuster(label: "Min BPM", value: $zone.minBPM, range: 30...220, step: 5)
                            Divider().frame(height: 60)
                            NumberAdjuster(label: "Max BPM", value: $zone.maxBPM, range: 30...220, step: 5)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))

                        if zone.minBPM >= zone.maxBPM {
                            Label("Max BPM must be greater than Min BPM",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                        }
                    }

                    // Weekly target
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            fieldLabel("Weekly Target")
                            Spacer()
                            Text("\(zone.weeklyTargetMinutes) min")
                                .font(.headline.monospacedDigit())
                        }
                        Slider(
                            value: Binding(
                                get: { Double(zone.weeklyTargetMinutes) },
                                set: { zone.weeklyTargetMinutes = (Int($0) / 10) * 10 }
                            ),
                            in: 0...600, step: 10
                        )
                        .tint(.blue)
                        HStack {
                            Text("0 min")
                            Spacer()
                            Text("600 min")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Delete button — only for existing zones
                    if !isNew {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Zone", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 12))
                        }
                        .confirmationDialog("Delete this zone?",
                                            isPresented: $showDeleteConfirm,
                                            titleVisibility: .visible) {
                            Button("Delete Zone", role: .destructive) {
                                onDelete()
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNew ? "New Zone" : "Edit Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(zone)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - Number Adjuster

private struct NumberAdjuster: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 0) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(value <= range.lowerBound ? Color.secondary.opacity(0.4) : .primary)
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .frame(minWidth: 48)
                    .multilineTextAlignment(.center)

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(value >= range.upperBound ? Color.secondary.opacity(0.4) : .primary)
                .disabled(value >= range.upperBound)
            }
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weekly Stats Row

extension ZonesView {
    var weeklyStatsRow: some View {
        HStack(spacing: 12) {
            ZoneStatCard(
                label: "Active Min",
                value: "\(Int(totalWeekMinutes))",
                subtitle: "this week"
            )
            ZoneStatCard(
                label: "On Target",
                value: "\(zonesOnTarget)/\(vm.zones.count)",
                subtitle: "zones"
            )
            ZoneStatCard(
                label: "Top Zone",
                value: topZone?.name ?? "—",
                subtitle: "most minutes"
            )
        }
    }

    // MARK: - Today Snapshot Card

    var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if totalTodayMinutes == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .foregroundStyle(.secondary)
                    Text("No heart rate data recorded today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                // Stacked bar
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    for zone in vm.zones {
                        let mins = vm.zoneMinutesToday[zone.id, default: 0]
                        guard mins > 0 else { continue }
                        let width = size.width * CGFloat(mins / totalTodayMinutes)
                        ctx.fill(
                            Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                            with: .color(bpmColor(for: zone, among: vm.zones))
                        )
                        x += width
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .frame(height: 20)

                // Legend
                VStack(spacing: 5) {
                    ForEach(vm.zones) { zone in
                        let mins = vm.zoneMinutesToday[zone.id, default: 0]
                        if mins > 0 {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(bpmColor(for: zone, among: vm.zones))
                                    .frame(width: 7, height: 7)
                                Text(zone.name)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(mins)) min")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Zone Stat Card

private struct ZoneStatCard: View {
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

// MARK: - BPM-adaptive color

/// Maps a zone's midpoint BPM to a heat gradient relative to all zones:
/// coolest zone → blue (hue 0.67), hottest zone → red (hue 0.0), middle → green (hue 0.33).
private func bpmColor(for zone: HeartRateZone, among zones: [HeartRateZone]) -> Color {
    let mid = Double(zone.minBPM + zone.maxBPM) / 2.0
    let allMids = zones.map { Double($0.minBPM + $0.maxBPM) / 2.0 }
    let lo = allMids.min() ?? mid
    let hi = allMids.max() ?? mid
    // t = 0 (lowest intensity) … 1 (highest intensity)
    let t = hi > lo ? (mid - lo) / (hi - lo) : 0.5
    return Color(hue: (1.0 - t) * 0.67, saturation: 0.75, brightness: 0.85)
}
