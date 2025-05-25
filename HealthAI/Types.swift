import Foundation

// types used throughout
struct HealthMetric: Identifiable {
    let id = UUID()
    let type: HealthMetricType
    let value: Double
    let date: Date
    let unit: String
}

enum HealthMetricType: String, CaseIterable, Identifiable {
    case steps
    case heartRate
    case energyBurned
    case exerciseTime
    case sleepDuration

    var id: String { rawValue }
}

struct Message: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}
