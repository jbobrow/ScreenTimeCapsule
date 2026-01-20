import SwiftUI
import Charts

struct UsageChartView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if dataManager.selectedTimePeriod == .today || dataManager.selectedTimePeriod == .yesterday {
                HourlyUsageChart()
            } else {
                WeeklyUsageChart()
            }

            CategoryBreakdownChart()
        }
    }
}

struct HourlyUsageChart: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage by Hour")
                .font(.headline)

            if dataManager.currentUsage.isEmpty {
                Text("No usage data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                chartView
            }
        }
    }

    private var chartView: some View {
        let data = dataManager.getHourlyUsageDataByCategory()
        let colorScale = getCategoryColorScale()

        return Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                BarMark(
                    x: .value("Hour", hourLabel(item.hour)),
                    y: .value("Usage", item.usage / 60)
                )
                .foregroundStyle(by: .value("Category", item.category.rawValue))
                .position(by: .value("Category", item.category.rawValue), axis: .horizontal)
            }
        }
        .chartForegroundStyleScale(colorScale)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))m")
                    }
                }
            }
        }
        .frame(height: 120)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }

    private func getCategoryColorScale() -> [String: Color] {
        var scale: [String: Color] = [:]
        for category in UsageCategory.allCases {
            scale[category.rawValue] = categoryColor(category)
        }
        return scale
    }

    private func categoryColor(_ category: UsageCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "teal": return .teal
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "indigo": return .indigo
        case "red": return .red
        case "brown": return .brown
        default: return .gray
        }
    }
}

struct WeeklyUsageChart: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage by Day")
                .font(.headline)

            if dataManager.currentUsage.isEmpty {
                Text("No usage data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                chartView
            }
        }
    }

    private var chartView: some View {
        let data = dataManager.getWeeklyUsageDataByCategory()
        let colorScale = getCategoryColorScale()

        return Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                BarMark(
                    x: .value("Day", item.day),
                    y: .value("Usage", item.usage / 3600)
                )
                .foregroundStyle(by: .value("Category", item.category.rawValue))
                .position(by: .value("Category", item.category.rawValue), axis: .horizontal)
            }
        }
        .chartForegroundStyleScale(colorScale)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                    }
                }
            }
        }
        .frame(height: 120)
    }

    private func getCategoryColorScale() -> [String: Color] {
        var scale: [String: Color] = [:]
        for category in UsageCategory.allCases {
            scale[category.rawValue] = categoryColor(category)
        }
        return scale
    }

    private func categoryColor(_ category: UsageCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "teal": return .teal
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "indigo": return .indigo
        case "red": return .red
        case "brown": return .brown
        default: return .gray
        }
    }
}

struct CategoryBreakdownChart: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category Breakdown")
                .font(.headline)

            if let summary = dataManager.usageSummary, !summary.categoryBreakdown.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(summary.categoryBreakdown.sorted(by: { $0.value > $1.value })), id: \.key) { category, time in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(categoryColor(category))
                                    .frame(width: 8, height: 8)
                                Text(category.rawValue)
                                    .font(.caption)
                                    .lineLimit(1)
                            }

                            Text(dataManager.formatDuration(time))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("No category data available")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func categoryColor(_ category: UsageCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "teal": return .teal
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "indigo": return .indigo
        case "red": return .red
        case "brown": return .brown
        default: return .gray
        }
    }
}

#Preview {
    UsageChartView()
        .environmentObject(ScreenTimeDataManager.shared)
        .padding()
        .frame(width: 800, height: 300)
}
