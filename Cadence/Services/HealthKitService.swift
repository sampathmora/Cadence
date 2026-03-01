import HealthKit

class HealthKitService {
    private let store = HKHealthStore()   // One instance per app (Apple's recommendation)

    // MARK: Permissions
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: Steps — daily totals for last 7 days
    func fetchWeeklySteps() async throws -> [Date: Double] {
        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: now)

        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: calendar.startOfDay(for: now),
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await query.result(for: store)
        var result: [Date: Double] = [:]
        collection.enumerateStatistics(from: weekStart, to: now) { stats, _ in
            result[stats.startDate] = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
        }
        return result
    }

    // MARK: Heart Rate — raw samples for last 7 days (ViewModel does zone math)
    func fetchWeeklyHeartRateSamples() async throws -> [HKQuantitySample] {
        let hrType = HKQuantityType(.heartRate)
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: now)
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: HKObjectQueryNoLimit
        )
        return try await query.result(for: store)
    }
}

enum HealthError: Error, LocalizedError {
    case notAvailable
    var errorDescription: String? { "Health data is not available on this device." }
}
