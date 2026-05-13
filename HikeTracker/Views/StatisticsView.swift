import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query(sort: \HikeRecord.startDate, order: .reverse) private var hikes: [HikeRecord]

    private var completedHikes: [HikeRecord] {
        hikes.filter { $0.endDate != nil && $0.totalDistance > 0 }
    }

    private var aggregate: (totalDistance: Double, totalDuration: TimeInterval, totalCount: Int) {
        StatisticsViewModel.aggregateStats(for: hikes)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 总览卡片
                overviewSection

                // 月度统计
                monthlyChartSection

                // 最近记录
                recentHikesSection
            }
            .padding()
        }
        .navigationTitle("数据统计")
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(spacing: 12) {
            Text("累计数据")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(
                    title: "总里程",
                    value: formatDistance(aggregate.totalDistance),
                    icon: "figure.walk"
                )
                StatCard(
                    title: "徒步次数",
                    value: "\(aggregate.totalCount)",
                    icon: "number"
                )
            }
            HStack(spacing: 12) {
                StatCard(
                    title: "总时长",
                    value: formatDuration(aggregate.totalDuration),
                    icon: "clock"
                )
                StatCard(
                    title: "平均距离",
                    value: aggregate.totalCount > 0 ? formatDistance(aggregate.totalDistance / Double(aggregate.totalCount)) : "--",
                    icon: "ruler"
                )
            }
        }
    }

    // MARK: - Monthly Chart

    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("月度里程")
                .font(.headline)

            if completedHikes.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(monthlyData, id: \.month) { item in
                    BarMark(
                        x: .value("月份", item.month),
                        y: .value("里程 (km)", item.distance)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartYAxisLabel("km")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var monthlyData: [(month: String, distance: Double)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月"

        let grouped = Dictionary(grouping: completedHikes) { hike in
            let components = calendar.dateComponents([.year, .month], from: hike.startDate)
            return "\(components.year ?? 0)-\(String(format: "%02d", components.month ?? 0))"
        }

        return grouped.map { key, hikes in
            let distance = hikes.reduce(0) { $0 + $1.totalDistance } / 1000.0
            let parts = key.split(separator: "-")
            let monthStr = parts.count == 2 ? "\(Int(parts[1]) ?? 0)月" : key
            return (month: monthStr, distance: distance)
        }.sorted { $0.month < $1.month }
    }

    // MARK: - Recent Hikes

    private var recentHikesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近徒步")
                .font(.headline)

            if completedHikes.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(completedHikes.prefix(5)) { hike in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hike.name)
                                .font(.subheadline)
                            Text(formatDate(hike.startDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(hike.formattedDistance)
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 4)
                    if hike.id != completedHikes.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000.0)
        }
        return String(format: "%.0f m", meters)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            let remainHours = hours % 24
            return String(format: "%dd %dh", days, remainHours)
        } else if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
