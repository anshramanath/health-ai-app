import SwiftUI
import Charts

struct HealthChartsView: View {
    @StateObject private var healthManager = HealthManager()
    @State private var selectedMetric: HealthMetricType = .steps
    @State private var dateRange: Int = 7 // Toggle between 7 (week) and 30 (month)
    
    // health trends ui
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Text("❤️ Health Trends")
                    .font(.title)
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .foregroundColor(.black)
                    .padding(.bottom, 60)
                
                // switch between metrics as well as week & month
                ScrollView {
                    VStack(spacing: 20) {
                        Picker("Metric", selection: $selectedMetric) {
                            ForEach(HealthMetricType.allCases, id: \.self) { metric in
                                Text(shortLabel(for: metric))
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        Picker("Range", selection: $dateRange) {
                            Text("Week").tag(7)
                            Text("Month").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if !filteredData().isEmpty {
                            Chart {
                                ForEach(filteredData()) { point in
                                    LineMark(
                                        x: .value("Day", point.date),
                                        y: .value("Value", point.value)
                                    )
                                    .interpolationMethod(.monotone)
                                }
                            }
                            .chartXAxis {
                                let data = filteredData()

                                // Prevent X-axis from being too crowded in 30-day view
                                let strideValue = dateRange == 30 ? max(1, data.count / 6) : 1

                                // Only display a subset of tick marks for clarity
                                let visibleTicks = data.enumerated()
                                    .filter { $0.offset % strideValue == 0 }
                                    .map { $0.element.date }

                                AxisMarks(values: visibleTicks) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(formattedDate(date))
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .frame(height: 400)
                            .padding(.horizontal)
                        } else {
                            Text("No data available")
                                .foregroundColor(.gray)
                                .frame(height: 400)
                        }

                        Text(healthManager.summary(for: selectedMetric, range: dateRange))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 24)
                    }
                }
            }
            .onAppear {
                healthManager.fetchAllData() // Kick off data fetch on view load
            }
        }
    }

    // Return sorted data limited to the selected metric and range
    private func filteredData() -> [HealthMetric] {
        let all = healthManager.chartData(for: selectedMetric, range: dateRange)
        return all.sorted(by: { $0.date < $1.date })
    }

    // Adjusts date format based on range: week vs month
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = dateRange == 7 ? "EEE" : "MMM d"
        return formatter.string(from: date)
    }

    // Short labels for each metric type to keep picker UI clean
    private func shortLabel(for metric: HealthMetricType) -> String {
        switch metric {
        case .steps: return "Steps"
        case .heartRate: return "Heartrate"
        case .energyBurned: return "Energy"
        case .exerciseTime: return "Exercise"
        case .sleepDuration: return "Sleep"
        }
    }
}

#Preview {
    HealthChartsView()
}
