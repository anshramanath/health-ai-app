import Foundation
import HealthKit

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var metrics: [HealthMetricType: [HealthMetric]] = [:]

    var useMockData = false

    // Fetch all health metrics, optionally using mock data for quick demoing
    func fetchAllData() {
        if useMockData {
            loadMockData()
            return
        }

        requestAuthorization {
            self.fetch(.steps, identifier: .stepCount)
            self.fetch(.heartRate, identifier: .heartRate)
            self.fetch(.energyBurned, identifier: .activeEnergyBurned)
            self.fetch(.exerciseTime, identifier: .appleExerciseTime)
            self.fetchSleepData()
        }
    }

    // Request permission to access HealthKit data
    private func requestAuthorization(completion: @escaping () -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let types: Set = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        healthStore.requestAuthorization(toShare: [], read: types) { success, _ in
            if success {
                DispatchQueue.main.async { completion() }
            }
        }
    }

    // Generic fetch method for quantity types
    private func fetch(_ type: HealthMetricType, identifier: HKQuantityTypeIdentifier) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        // Date range: last 30 days
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
        let endDate = calendar.date(byAdding: .day, value: 1, to: now)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Daily interval
        var interval = DateComponents()
        interval.day = 1

        // Determine unit for this metric
        let unit: HKUnit = {
            switch identifier {
            case .stepCount: return .count()
            case .heartRate: return HKUnit.count().unitDivided(by: .minute())
            case .activeEnergyBurned: return .kilocalorie()
            case .appleExerciseTime: return .minute()
            default: return .count()
            }
        }()

        // Determine stats option: sum or average
        let options: HKStatisticsOptions = {
            switch identifier {
            case .heartRate: return .discreteAverage
            default: return .cumulativeSum
            }
        }()

        // Query health data
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: options,
            anchorDate: startDate,
            intervalComponents: interval
        )

        // Process and store results
        query.initialResultsHandler = { _, results, _ in
            guard let stats = results else { return }
            var data: [HealthMetric] = []

            stats.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                let quantity = (options == .discreteAverage
                                ? stat.averageQuantity()
                                : stat.sumQuantity())
                let value = quantity?.doubleValue(for: unit) ?? 0
                data.append(HealthMetric(type: type, value: value, date: stat.startDate, unit: unit.unitString))
            }

            DispatchQueue.main.async {
                self.metrics[type] = data
            }
        }

        healthStore.execute(query)
    }

    // Fetch and process sleep data (handled differently since it's a category type)
    private func fetchSleepData() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
        let endDate = calendar.date(byAdding: .day, value: 1, to: now)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Query all sleep samples
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var data: [HealthMetric] = []

            // Group samples by day
            let grouped = Dictionary(grouping: samples as? [HKCategorySample] ?? [], by: {
                Calendar.current.startOfDay(for: $0.startDate)
            })

            for (date, daySamples) in grouped {
                let totalSleepSeconds = daySamples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let hours = totalSleepSeconds / 3600.0
                data.append(HealthMetric(type: .sleepDuration, value: hours, date: date, unit: "hr"))
            }

            DispatchQueue.main.async {
                self.metrics[.sleepDuration] = data
            }
        }

        healthStore.execute(query)
    }

    // Generate 30 days of fake data for each metric type
    private func loadMockData() {
        metrics = [
            .steps: generateMock(.steps, values: [9263, 10485, 8900, 9383, 4065, 9555, 8226, 11744, 3926, 3278, 9078, 3575, 6568, 11571, 5581, 4616, 9122, 3629, 6265, 4633, 11326, 10217, 5432, 7302, 8258, 11468, 5070, 9743, 3303, 9451]),
            .heartRate: generateMock(.heartRate, values: [66, 72, 72, 73, 84, 83, 72, 81, 70, 77, 67, 66, 66, 67, 78, 88, 77, 76, 78, 79, 72, 87, 85, 84, 77, 73, 63, 63, 82, 77]),
            .energyBurned: generateMock(.energyBurned, values: [191, 389, 250, 363, 387, 334, 175, 307, 293, 287, 314, 370, 352, 230, 186, 180, 324, 306, 212, 204, 172, 250, 331, 252, 315, 213, 250, 397, 155, 309]),
            .exerciseTime: generateMock(.exerciseTime, values: [41, 16, 34, 38, 11, 24, 49, 35, 59, 32, 35, 49, 48, 53, 29, 16, 15, 54, 26, 17, 19, 57, 12, 31, 57, 43, 50, 29, 57, 41]),
            .sleepDuration: generateMock(.sleepDuration, values: [7.2, 7.2, 6.2, 6.0, 8.4, 8.0, 6.4, 7.5, 8.4, 5.8, 7.1, 5.7, 5.5, 7.7, 6.7, 8.0, 5.6, 8.0, 5.7, 8.4, 6.3, 8.1, 8.1, 7.0, 8.1, 5.5, 5.5, 6.8, 7.9, 5.8])
        ]
    }

    // Map values to days and wrap them in HealthMetric objects
    private func generateMock(_ type: HealthMetricType, values: [Double]) -> [HealthMetric] {
        let now = Date()
        return values.enumerated().map { index, value in
            let date = Calendar.current.date(byAdding: .day, value: -index, to: now)!
            let unit = defaultUnit(for: type)
            return HealthMetric(type: type, value: value, date: date, unit: unit)
        }.reversed()
    }

    // Extract and fill in chart data for the given range
    func chartData(for type: HealthMetricType, range: Int = 7) -> [HealthMetric] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -range + 1, to: calendar.startOfDay(for: now))!

        let dataByDate = Dictionary(grouping: metrics[type] ?? [], by: { calendar.startOfDay(for: $0.date) })

        var result: [HealthMetric] = []

        for offset in 0..<range {
            if let date = calendar.date(byAdding: .day, value: offset, to: startDate) {
                if let entry = dataByDate[date]?.first {
                    result.append(entry)
                } else {
                    // Fill in missing days with zero value
                    result.append(HealthMetric(type: type, value: 0, date: date, unit: defaultUnit(for: type)))
                }
            }
        }

        return result
    }

    // Provide unit label for each metric
    private func defaultUnit(for type: HealthMetricType) -> String {
        switch type {
        case .steps: return "count"
        case .heartRate: return "count/min"
        case .energyBurned: return "kcal"
        case .exerciseTime: return "min"
        case .sleepDuration: return "hr"
        }
    }

    // Generate readable summary string
    func summary(for type: HealthMetricType, range: Int = 7) -> String {
        let values = chartData(for: type, range: range)
        let total = values.reduce(0) { $0 + $1.value }
        let avg = values.isEmpty ? 0 : total / Double(values.count)
        let unit = values.first?.unit ?? ""
        return "Total: \(Int(total)) \(unit), Avg/Day: \(Int(avg)) \(unit)"
    }

    // Returns a short summary for display in chat
    var weeklySummary: String {
        let steps = Int(metrics[.steps]?.last?.value ?? 0)
        let heartRate = Int(metrics[.heartRate]?.last?.value ?? 0)
        let energy = Int(metrics[.energyBurned]?.last?.value ?? 0)
        let exercise = Int(metrics[.exerciseTime]?.last?.value ?? 0)
        let sleep = Int(metrics[.sleepDuration]?.last?.value ?? 0)

        return "Hey! Here's where you're at: \(steps) steps, heart rate: \(heartRate) bpm, \(energy) kcals burned, \(exercise) mins exercised, \(sleep) hours slept."
    }
}

