import Foundation
import CoreLocation
import SwiftData
import MapKit

enum RecordingState {
    case idle
    case recording
    case paused
}

@Observable
final class RecordingViewModel {
    var state: RecordingState = .idle
    var currentHike: HikeRecord?
    var trackedLocations: [CLLocation] = []
    var currentDistance: Double = 0
    var currentDuration: TimeInterval = 0
    var currentAltitude: Double = 0
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    var maxAltitude: Double = -Double.infinity
    var minAltitude: Double = Double.infinity

    private var timer: Timer?
    private var recordingStartTime: Date?
    private var accumulatedDuration: TimeInterval = 0
    var lastLocation: CLLocation?

    private let locationManager: LocationManager
    private var modelContext: ModelContext?

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startRecording() {
        guard locationManager.isAuthorized else { return }

        state = .recording
        trackedLocations = []
        currentDistance = 0
        currentDuration = 0
        accumulatedDuration = 0
        elevationGain = 0
        elevationLoss = 0
        maxAltitude = -Double.infinity
        minAltitude = Double.infinity
        lastLocation = nil

        currentHike = HikeRecord(
            name: formatDate(Date.now),
            startDate: Date.now
        )

        recordingStartTime = Date.now
        startTimer()
        locationManager.startUpdatingLocation()

        locationManager.onLocationUpdate = { [weak self] location in
            self?.addLocation(location)
        }
    }

    func pauseRecording() {
        state = .paused
        accumulatedDuration = currentDuration
        stopTimer()
        locationManager.stopUpdatingLocation()
    }

    func resumeRecording() {
        state = .recording
        recordingStartTime = Date.now
        startTimer()
        locationManager.startUpdatingLocation()

        locationManager.onLocationUpdate = { [weak self] location in
            self?.addLocation(location)
        }
    }

    func stopRecording() {
        stopTimer()
        locationManager.stopUpdatingLocation()
        locationManager.onLocationUpdate = nil

        state = .idle

        guard let hike = currentHike else { return }
        hike.endDate = Date.now
        hike.totalDistance = currentDistance
        hike.duration = currentDuration
        hike.elevationGain = elevationGain
        hike.elevationLoss = elevationLoss
        hike.maxAltitude = maxAltitude == -Double.infinity ? 0 : maxAltitude
        hike.minAltitude = minAltitude == Double.infinity ? 0 : minAltitude

        // 保存轨迹点
        for location in trackedLocations {
            let point = LocationPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy,
                speed: location.speed,
                course: location.course
            )
            hike.locations.append(point)
        }

        modelContext?.insert(hike)
        try? modelContext?.save()
        currentHike = hike
    }

    // MARK: - Private

    func addLocation(_ location: CLLocation) {
        if let last = lastLocation {
            let distance = location.distance(from: last)
            // 过滤距离太近的点（小于 5 米视为漂移）
            guard distance >= 5 else { return }

            // 过滤方向突变：如果新点相对上一个点偏转角度超过 90° 且距离 < 15m，视为抖动
            if distance < 15, let prevPrev = trackedLocations.count >= 2 ? trackedLocations[trackedLocations.count - 2] : nil {
                let bearing1 = bearing(from: prevPrev, to: last)
                let bearing2 = bearing(from: last, to: location)
                let angleDiff = abs(angleDifference(bearing1, bearing2))
                if angleDiff > 90 {
                    return
                }
            }

            currentDistance += distance

            // 计算海拔变化
            let altitudeDiff = location.altitude - last.altitude
            if altitudeDiff > 0 {
                elevationGain += altitudeDiff
            } else {
                elevationLoss += abs(altitudeDiff)
            }
        }

        trackedLocations.append(location)
        lastLocation = location
        currentAltitude = location.altitude

        if location.altitude > maxAltitude {
            maxAltitude = location.altitude
        }
        if location.altitude < minAltitude {
            minAltitude = location.altitude
        }
    }

    /// 计算两点间的方位角（0~360°）
    private func bearing(from: CLLocation, to: CLLocation) -> Double {
        let lat1 = from.coordinate.latitude * .pi / 180
        let lon1 = from.coordinate.longitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let lon2 = to.coordinate.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    /// 计算两个方位角之差（-180~180°）
    private func angleDifference(_ a1: Double, _ a2: Double) -> Double {
        var diff = a2 - a1
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            self.currentDuration = self.accumulatedDuration + Date.now.timeIntervalSince(start)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
