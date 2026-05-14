import Testing
import CoreLocation
import SwiftData
@testable import HikeTracker

@MainActor
struct RecordingViewModelTests {

    private let coordinates: [[Double]] = [
        [29.82317509616626, 121.56942592909225],
        [29.822802806856423, 121.56876791061592],
        [29.822790409431988, 121.56793825076825],
        [29.81976895805055, 121.56791430837399],
        [29.815685268281584, 121.56721612215448],
        [29.81536280187602, 121.57031617848013],
        [29.818878213373438, 121.57192970883365],
        [29.818689454881195, 121.57414143999864],
        [29.822731691266977, 121.57559180917727],
        [29.822826086051386, 121.56875712048401]
    ]

    private func makeLocation(
        lat: Double, lng: Double,
        altitude: Double = 50,
        accuracy: Double = 15,
        speed: Double = 1.5,
        index: Int = 0
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            course: 0,
            speed: speed,
            timestamp: Date().addingTimeInterval(Double(index) * 10)
        )
    }

    // MARK: - 端到端测试：startRecording → 写入轨迹 → stopRecording → 持久化

    @Test func testFullRecordingFlow() async throws {
        let locationManager = LocationManager()

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HikeRecord.self, LocationPoint.self, configurations: config)
        let context = container.mainContext

        let viewModel = RecordingViewModel(locationManager: locationManager)
        viewModel.configure(modelContext: context)

        // 1. 手动初始化录制状态（不启动真实 GPS）
        viewModel.state = .recording
        viewModel.currentHike = HikeRecord(name: "Test Hike", startDate: Date.now)

        // 2. 注入测试坐标
        for (index, coord) in coordinates.enumerated() {
            let location = makeLocation(
                lat: coord[0], lng: coord[1],
                altitude: 50 + Double(index) * 2,
                index: index
            )
            viewModel.addLocation(location)
        }

        // 3. 验证 trackedLocations 在 stopRecording 之前的顺序
        #expect(viewModel.trackedLocations.count == coordinates.count)
        for (index, coord) in coordinates.enumerated() {
            let loc = viewModel.trackedLocations[index]
            #expect(abs(loc.coordinate.latitude - coord[0]) < 0.0000001)
            #expect(abs(loc.coordinate.longitude - coord[1]) < 0.0000001)
        }

        // 4. stopRecording → 保存到 SwiftData
        viewModel.stopRecording()
        #expect(viewModel.state == .idle)

        // 5. 验证 HikeRecord 基本信息
        let hike = try #require(viewModel.currentHike)
        #expect(hike.endDate != nil)
        #expect(hike.totalDistance > 0)
        #expect(hike.elevationGain > 0)
        #expect(hike.maxAltitude > 0)
        #expect(hike.minAltitude > 0)

        // 6. 验证轨迹点数量和坐标（集合匹配，容忍 SwiftData 排序差异）
        #expect(hike.locations.count == coordinates.count)
        for coord in coordinates {
            let found = hike.locations.contains { point in
                abs(point.latitude - coord[0]) < 0.0000001 &&
                abs(point.longitude - coord[1]) < 0.0000001
            }
            #expect(found, "Coordinate \(coord) not found in saved locations")
        }

        // 7. 验证 SwiftData 持久化
        let descriptor = FetchDescriptor<HikeRecord>()
        let savedHikes = try context.fetch(descriptor)
        #expect(savedHikes.count == 1)
        #expect(savedHikes[0].locations.count == coordinates.count)
        #expect(abs(savedHikes[0].totalDistance - hike.totalDistance) < 1.0)

        print("===== 端到端录制测试 =====")
        print("轨迹点数: \(savedHikes[0].locations.count)")
        print("总距离: \(String(format: "%.2f", savedHikes[0].totalDistance)) m")
        print("累计爬升: \(String(format: "%.2f", savedHikes[0].elevationGain)) m")
        print("累计下降: \(String(format: "%.2f", savedHikes[0].elevationLoss)) m")
        print("最高海拔: \(String(format: "%.2f", savedHikes[0].maxAltitude)) m")
        print("最低海拔: \(String(format: "%.2f", savedHikes[0].minAltitude)) m")
    }

    // MARK: - LocationManager 过滤链路测试

    @Test func testLocationManagerAccuracyFilter() async throws {
        let locationManager = LocationManager()
        let viewModel = RecordingViewModel(locationManager: locationManager)

        // 手动初始化录制状态
        viewModel.state = .recording
        viewModel.currentHike = HikeRecord(name: "Filter Test", startDate: Date.now)

        // 设置回调（模拟 startRecording 的行为）
        locationManager.onLocationUpdate = { [weak viewModel] location in
            viewModel?.addLocation(location)
        }

        let dummyManager = CLLocationManager()
        var expectedCount = 0

        for (index, coord) in coordinates.enumerated() {
            let accuracy: Double = index % 2 == 0 ? 15 : 30
            if accuracy <= 20 { expectedCount += 1 }

            let location = makeLocation(
                lat: coord[0], lng: coord[1],
                altitude: 50 + Double(index) * 2,
                accuracy: accuracy,
                index: index
            )
            // 走完整 LocationManager delegate → 过滤 → onLocationUpdate → addLocation
            locationManager.locationManager(dummyManager, didUpdateLocations: [location])
        }

        #expect(viewModel.trackedLocations.count == expectedCount)
        print("精度过滤: \(coordinates.count) 个点中 \(expectedCount) 个通过，实际记录 \(viewModel.trackedLocations.count) 个")
    }
}
