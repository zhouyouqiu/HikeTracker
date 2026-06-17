import SwiftUI
import MapKit
import Charts

struct HikeDetailView: View {
    let hike: HikeRecord

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var trackPolyline: MKPolyline?
    @State private var simplifiedCoords: [CLLocationCoordinate2D] = []

    // 回放状态
    @State private var replayIndex: Int = 0
    @State private var replayProgress: Double = 0
    @State private var isReplaying = false
    @State private var replayTimer: Timer?
    @State private var replayPolyline: MKPolyline?

    private var stats: StatisticsViewModel { StatisticsViewModel(hike: hike) }

    private var isReplayActive: Bool { isReplaying || replayIndex > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 地图
                mapSection
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // 基础统计
                basicStatsSection

                // 时间信息
                timeInfoSection

                // 海拔统计
                elevationStatsSection

                // 配速图表
                paceChartSection

                // 海拔剖面图
                altitudeChartSection
            }
            .padding()
        }
        .navigationTitle(hike.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if trackPolyline == nil && !hike.sortedLocations.isEmpty {
                let converted = CoordinateConverter.wgs84ToGcj02(hike.sortedLocations.map { $0.coordinate })
                let simplified = CoordinateConverter.simplify(converted, epsilon: 10.0)
                let smoothed = CoordinateConverter.smoothPath(simplified, segments: 10)
                simplifiedCoords = smoothed
                trackPolyline = MKPolyline(coordinates: smoothed, count: smoothed.count)
            }
            setCameraToTrack()
        }
        .onDisappear {
            replayTimer?.invalidate()
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Group {
            if hike.locations.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.gray.opacity(0.15))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("无轨迹数据")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                MapOverlayView(
                    polyline: isReplayActive ? replayPolyline : trackPolyline,
                    ghostPolyline: isReplayActive ? trackPolyline : nil,
                    currentPosition: leadingCoordinate,
                    cameraPosition: $cameraPosition
                )
                .overlay(alignment: .bottomTrailing) { replayControls }
            }
        }
    }

    private var leadingCoordinate: CLLocationCoordinate2D? {
        guard isReplayActive, replayIndex > 0, replayIndex <= simplifiedCoords.count else { return nil }
        return simplifiedCoords[replayIndex - 1]
    }

    private var replayControls: some View {
        HStack(spacing: 12) {
            if replayIndex > 0 && !isReplaying {
                Button {
                    resetReplay()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.9), in: Circle())
                        .shadow(radius: 2)
                }
            }

            Button {
                isReplaying ? pauseReplay() : startReplay()
            } label: {
                Image(systemName: isReplaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.9), in: Circle())
                    .shadow(radius: 2)
            }
        }
        .padding(12)
    }

    // MARK: - Replay

    private func startReplay() {
        guard !simplifiedCoords.isEmpty else { return }
        if replayProgress >= 1.0 { resetReplay() }
        isReplaying = true

        // ~25 秒、30fps → 750 帧；进度 0..1 作为缓动输入，索引由缓动后的值推导
        let totalTicks = 750
        replayTimer?.invalidate()
        replayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            replayProgress = min(replayProgress + 1.0 / Double(totalTicks), 1.0)
            updateReplayPolyline()
            if replayProgress >= 1.0 {
                pauseReplay()
            }
        }
    }

    private func updateReplayPolyline() {
        let eased = easeInOut(replayProgress)
        let count = simplifiedCoords.count
        let idx = max(1, min(Int(eased * Double(count)), count))
        replayIndex = idx
        replayPolyline = MKPolyline(coordinates: Array(simplifiedCoords[0..<idx]), count: idx)
    }

    /// ease-in-out：起停柔和、中段稍快
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func pauseReplay() {
        replayTimer?.invalidate()
        replayTimer = nil
        isReplaying = false
    }

    private func resetReplay() {
        pauseReplay()
        replayProgress = 0
        replayIndex = 0
        replayPolyline = nil
    }

    private func setCameraToTrack() {
        guard let polyline = trackPolyline else { return }
        let mapRect = polyline.boundingMapRect
        cameraPosition = .camera(MapCamera(
            centerCoordinate: polyline.coordinate,
            distance: max(mapRect.size.width, mapRect.size.height) * 1.5,
            heading: 0,
            pitch: 0
        ))
    }

    // MARK: - Stats Sections

    private var basicStatsSection: some View {
        VStack(spacing: 12) {
            Text("运动数据")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(title: "距离", value: hike.formattedDistance, icon: "figure.walk")
                StatCard(title: "时长", value: hike.formattedDuration, icon: "clock")
            }
            HStack(spacing: 12) {
                StatCard(title: "配速", value: hike.formattedPace, icon: "gauge.with.dots.needle.bottom.50percent", subtitle: "min/km")
                StatCard(title: "均速", value: String(format: "%.1f km/h", hike.averageSpeed), icon: "speedometer")
            }
        }
    }

    private var elevationStatsSection: some View {
        VStack(spacing: 12) {
            Text("海拔数据")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(title: "最高海拔", value: String(format: "%.0f m", hike.maxAltitude), icon: "arrow.up")
                StatCard(title: "最低海拔", value: String(format: "%.0f m", hike.minAltitude), icon: "arrow.down")
            }
            HStack(spacing: 12) {
                StatCard(title: "累计爬升", value: String(format: "%.0f m", hike.elevationGain), icon: "arrow.up.circle")
                StatCard(title: "累计下降", value: String(format: "%.0f m", hike.elevationLoss), icon: "arrow.down.circle")
            }
        }
    }

    private var timeInfoSection: some View {
        VStack(spacing: 12) {
            Text("时间信息")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(title: "开始", value: formatTime(hike.startDate), icon: "play.circle")
                StatCard(title: "结束", value: hike.endDate.map(formatTime) ?? "--", icon: "stop.circle")
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Charts

    private var paceChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分段配速")
                .font(.headline)

            if stats.pacePerKm.isEmpty {
                Text("数据不足")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(stats.pacePerKm, id: \.km) { item in
                    LineMark(
                        x: .value("公里", item.km),
                        y: .value("配速 (min/km)", item.pace)
                    )
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("公里", item.km),
                        y: .value("配速 (min/km)", item.pace)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 180)
                .chartYAxisLabel("min/km")
                .chartXAxisLabel("km")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var altitudeChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("海拔剖面")
                .font(.headline)

            if stats.altitudeProfile.isEmpty {
                Text("数据不足")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(stats.altitudeProfile, id: \.distance) { item in
                    AreaMark(
                        x: .value("距离", item.distance / 1000.0),
                        y: .value("海拔 (m)", item.altitude)
                    )
                    .foregroundStyle(.linearGradient(
                        colors: [.green.opacity(0.3), .green.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("距离", item.distance / 1000.0),
                        y: .value("海拔 (m)", item.altitude)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 180)
                .chartYAxisLabel("海拔 (m)")
                .chartXAxisLabel("距离 (km)")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
