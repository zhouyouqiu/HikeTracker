import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HikeRecord.startDate, order: .reverse) private var hikes: [HikeRecord]

    var body: some View {
        List {
            if hikes.isEmpty {
                ContentUnavailableView(
                    "暂无徒步记录",
                    systemImage: "figure.walk",
                    description: Text("开始你的第一次徒步记录吧")
                )
            } else {
                ForEach(groupedHikes, id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.value) { hike in
                            NavigationLink(destination: HikeDetailView(hike: hike)) {
                                HikeRowView(hike: hike)
                            }
                        }
                        .onDelete { offsets in
                            deleteHikes(at: offsets, in: group.value)
                        }
                    }
                }
            }
        }
        .navigationTitle("历史记录")
    }

    // MARK: - Grouping

    private var groupedHikes: [(key: String, value: [HikeRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: hikes) { hike in
            if calendar.isDateInToday(hike.startDate) {
                return "今天"
            } else if calendar.isDateInYesterday(hike.startDate) {
                return "昨天"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy年MM月"
                return formatter.string(from: hike.startDate)
            }
        }
        return grouped.sorted { a, b in
            let maxA = a.value.map(\.startDate).max() ?? .distantPast
            let maxB = b.value.map(\.startDate).max() ?? .distantPast
            return maxA > maxB
        }
    }

    private func deleteHikes(at offsets: IndexSet, in hikes: [HikeRecord]) {
        for index in offsets {
            let hike = hikes[index]
            modelContext.delete(hike)
        }
        try? modelContext.save()
    }
}

struct HikeRowView: View {
    let hike: HikeRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hike.displayName)
                    .font(.headline)

                let timeFormatter = DateFormatter()
                Text(timeFormatter.timeString(from: hike.startDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(hike.formattedDistance)
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                Text(hike.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension DateFormatter {
    func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
