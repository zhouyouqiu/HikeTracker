import SwiftUI
import MapKit
import Charts

struct HikeDetailView: View {
    let hike: HikeRecord

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var trackPolyline: MKPolyline?

    private var stats: StatisticsViewModel { StatisticsViewModel(hike: hike) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 地图
                mapSection
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // 基础统计
                basicStatsSection

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
            if trackPolyline == nil && !hike.locations.isEmpty {
                let converted = CoordinateConverter.wgs84ToGcj02(hike.locations.map { $0.coordinate })
                let simplified = CoordinateConverter.simplify(converted, epsilon: 10.0)
                trackPolyline = MKPolyline(coordinates: simplified, count: simplified.count)
            }
            setCameraToTrack()
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
                    polyline: trackPolyline,
                    cameraPosition: $cameraPosition
                )
            }
        }
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
