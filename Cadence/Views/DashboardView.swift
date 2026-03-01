import SwiftUI

struct DashboardView: View {
    @Environment(HealthViewModel.self) var vm

    private let zoneColors: [Color] = [.blue, .teal, .green, .orange, .red]

    private var stepsProgress: Double {
        min(vm.todaySteps / Double(vm.dailyStepGoal), 1.0)
    }

    private var zoneSegments: [(color: Color, minutes: Double)] {
        vm.zones.enumerated().map { i, zone in
            (zoneColors[i % zoneColors.count], vm.zoneMinutesToday[zone.id, default: 0])
        }
    }

    private var totalZoneMinutes: Double {
        zoneSegments.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                stepsCard
                zonesCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .overlay { if vm.isLoading { ProgressView() } }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.largeTitle.bold())
                Text(Date(), format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Steps Today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(Int(vm.todaySteps).formatted())
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)

                // Pill badge
                if stepsProgress >= 1.0 {
                    Label("Goal reached!", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue, in: Capsule())
                } else {
                    let remaining = max(vm.dailyStepGoal - Int(vm.todaySteps), 0)
                    Text("\(remaining.formatted()) steps to go")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: stepsProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8), value: stepsProgress)
                Image(systemName: "figure.walk")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 90, height: 90)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Zones Card

    private var zonesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Heart Rate Zones — Today")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if totalZoneMinutes == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .foregroundStyle(.secondary)
                    Text("No heart rate data recorded today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                // Stacked bar
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    for seg in zoneSegments where seg.minutes > 0 {
                        let width = size.width * CGFloat(seg.minutes / totalZoneMinutes)
                        ctx.fill(
                            Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                            with: .color(seg.color)
                        )
                        x += width
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(height: 22)

                // Legend
                VStack(spacing: 6) {
                    ForEach(Array(zip(vm.zones, zoneSegments).enumerated()), id: \.offset) { _, pair in
                        let (zone, seg) = pair
                        if seg.minutes > 0 {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(seg.color)
                                    .frame(width: 8, height: 8)
                                Text(zone.name)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(seg.minutes)) min")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

}
