import Foundation
import CoreLocation
import SwiftData

@Model
final class HikeRecord {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var totalDistance: Double
    var duration: TimeInterval
    var elevationGain: Double
    var elevationLoss: Double
    var maxAltitude: Double
    var minAltitude: Double
    @Relationship(deleteRule: .cascade) var locations: [LocationPoint]

    init(
        id: UUID = UUID(),
        name: String = "",
        startDate: Date = .now,
        endDate: Date? = nil,
        totalDistance: Double = 0,
        duration: TimeInterval = 0,
        elevationGain: Double = 0,
        elevationLoss: Double = 0,
        maxAltitude: Double = -Double.infinity,
        minAltitude: Double = Double.infinity,
        locations: [LocationPoint] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.totalDistance = totalDistance
        self.duration = duration
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.maxAltitude = maxAltitude
        self.minAltitude = minAltitude
        self.locations = locations
    }

    /// 平均配速（分钟/公里）
    var averagePace: Double {
        guard totalDistance > 0 else { return 0 }
        return (duration / 60.0) / (totalDistance / 1000.0)
    }

    /// 平均速度（km/h）
    var averageSpeed: Double {
        guard duration > 0 else { return 0 }
        return (totalDistance / 1000.0) / (duration / 3600.0)
    }

    /// 格式化距离
    var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f km", totalDistance / 1000.0)
        }
        return String(format: "%.0f m", totalDistance)
    }

    /// 格式化时长
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    /// 格式化配速
    var formattedPace: String {
        guard averagePace > 0, averagePace.isFinite else { return "--'--\"" }
        let paceMin = Int(averagePace)
        let paceSec = Int((averagePace - Double(paceMin)) * 60)
        return String(format: "%d'%02d\"", paceMin, paceSec)
    }

    /// 显示名称（name 为空时回退到日期）
    var displayName: String {
        if !name.isEmpty {
            return name
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: startDate)
    }

}

@Model
final class LocationPoint {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var timestamp: Date
    var horizontalAccuracy: Double
    var speed: Double
    var course: Double

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double,
        timestamp: Date,
        horizontalAccuracy: Double,
        speed: Double,
        course: Double
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
