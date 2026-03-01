import HealthKit
import Observation

@Observable
class HealthViewModel {
    var zones: [HeartRateZone] = ZoneStore.load()
    var weeklySteps: [Date: Double] = [:]
    var todaySteps: Double = 0
    var zoneMinutesThisWeek: [UUID: Double] = [:]
    var zoneMinutesToday: [UUID: Double] = [:]
    var dailyStepGoal: Int = {
        let saved = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        return saved == 0 ? 10_000 : saved
    }() {
        didSet { UserDefaults.standard.set(dailyStepGoal, forKey: "dailyStepGoal") }
    }
    var isLoading = false
    var errorMessage: String? = nil

    private let healthService = HealthKitService()

    // Called once from ContentView .task modifier
    func onAppear() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await healthService.requestAuthorization()
            await refreshData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshData() async {
        async let stepsTask = healthService.fetchWeeklySteps()
        async let hrTask = healthService.fetchWeeklyHeartRateSamples()
        do {
            let (steps, hrSamples) = try await (stepsTask, hrTask)
            weeklySteps = steps
            let todayStart = Calendar.current.startOfDay(for: Date())
            todaySteps = steps[todayStart] ?? 0
            zoneMinutesThisWeek = computeZoneMinutes(samples: hrSamples, zones: zones)
            zoneMinutesToday = computeZoneMinutes(
                samples: hrSamples.filter { $0.startDate >= todayStart },
                zones: zones
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveZones(_ updatedZones: [HeartRateZone]) {
        zones = updatedZones
        ZoneStore.save(zones)
        Task { await refreshData() }
    }

    // MARK: - Zone Calculation
    // HR samples are sparse. Strategy:
    //   1. Use the sample's own duration (endDate - startDate).
    //   2. Fill the gap to the next sample (capped at 3 min) at the same BPM.
    //   3. Each sample belongs to exactly one zone (first match wins).
    private func computeZoneMinutes(
        samples: [HKQuantitySample],
        zones: [HeartRateZone]
    ) -> [UUID: Double] {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let maxGapSeconds: Double = 3 * 60
        var result: [UUID: Double] = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, 0.0) })

        for (index, sample) in samples.enumerated() {
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            let sampleDuration = sample.endDate.timeIntervalSince(sample.startDate)
            let gapDuration: TimeInterval = index + 1 < samples.count
                ? min(max(samples[index + 1].startDate.timeIntervalSince(sample.endDate), 0), maxGapSeconds)
                : 0
            let totalMinutes = (sampleDuration + gapDuration) / 60.0

            for zone in zones where bpm >= Double(zone.minBPM) && bpm < Double(zone.maxBPM) {
                result[zone.id, default: 0] += totalMinutes
                break
            }
        }
        return result
    }
}
