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
                Chart {
                    ForEach(Array(dataManager.getHourlyUsageDataByCategory().enumerated()), id: \.offset) { index, data in
                        BarMark(
                            x: .value("Hour", data.hour),
                            y: .value("Usage", data.usage / 60), // Convert to minutes
                            stacking: .standard
                        )
                        .foregroundStyle(by: .value("Category", data.category.rawValue))
                    }
                }
                .chartForegroundStyleScale(categoryColorScale())
                .chartXScale(domain: 0...24)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                        if let hour = value.as(Int.self) {
                            AxisValueLabel {
                                Text(xAxisLabel(hour))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(yAxisLabel(minutes))
                            }
                        }
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private func xAxisLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12am"
        case 6: return "6am"
        case 12: return "12pm"
        case 18: return "6pm"
        case 24: return "12am"
        default: return ""
        }
    }

    private func yAxisLabel(_ minutes: Double) -> String {
        if minutes > 90 {
            let hours = minutes / 60
            return String(format: "%.0fh", hours)
        } else {
            return "\(Int(minutes))m"
        }
    }

    private func categoryColorScale() -> KeyValuePairs<String, Color> {
        return [
            UsageCategory.productivity.rawValue: categoryColor(.productivity),
            UsageCategory.creativity.rawValue: categoryColor(.creativity),
            UsageCategory.social.rawValue: categoryColor(.social),
            UsageCategory.entertainment.rawValue: categoryColor(.entertainment),
            UsageCategory.utilities.rawValue: categoryColor(.utilities),
            UsageCategory.other.rawValue: categoryColor(.other)
        ]
    }

    private func categoryColor(_ category: UsageCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "teal": return .teal
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
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
                Chart {
                    ForEach(Array(dataManager.getDailyUsageDataByCategory().enumerated()), id: \.offset) { index, data in
                        BarMark(
                            x: .value("Day", data.day),
                            y: .value("Usage", data.usage / 3600), // Convert to hours
                            stacking: .standard
                        )
                        .foregroundStyle(by: .value("Category", data.category.rawValue))
                    }
                }
                .chartForegroundStyleScale(categoryColorScale())
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
        }
    }

    private func categoryColorScale() -> KeyValuePairs<String, Color> {
        return [
            UsageCategory.productivity.rawValue: categoryColor(.productivity),
            UsageCategory.creativity.rawValue: categoryColor(.creativity),
            UsageCategory.social.rawValue: categoryColor(.social),
            UsageCategory.entertainment.rawValue: categoryColor(.entertainment),
            UsageCategory.utilities.rawValue: categoryColor(.utilities),
            UsageCategory.other.rawValue: categoryColor(.other)
        ]
    }

    private func categoryColor(_ category: UsageCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "teal": return .teal
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
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
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
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
