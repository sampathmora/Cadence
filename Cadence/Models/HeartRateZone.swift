import Foundation

struct HeartRateZone: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String               // "Zone 2"
    var minBPM: Int                // 100
    var maxBPM: Int                // 140
    var weeklyTargetMinutes: Int   // 150
}

extension HeartRateZone {
    static var defaults: [HeartRateZone] {
        [
            HeartRateZone(name: "Zone 1", minBPM: 30,  maxBPM: 100, weeklyTargetMinutes: 60),
            HeartRateZone(name: "Zone 2", minBPM: 100, maxBPM: 140, weeklyTargetMinutes: 150),
            HeartRateZone(name: "Zone 3", minBPM: 140, maxBPM: 170, weeklyTargetMinutes: 60),
        ]
    }
}

// UserDefaults persistence — one JSON-encoded key holds the full array
enum ZoneStore {
    private static let key = "heartRateZones"

    static func load() -> [HeartRateZone] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let zones = try? JSONDecoder().decode([HeartRateZone].self, from: data)
        else { return HeartRateZone.defaults }
        return zones
    }

    static func save(_ zones: [HeartRateZone]) {
        if let data = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
