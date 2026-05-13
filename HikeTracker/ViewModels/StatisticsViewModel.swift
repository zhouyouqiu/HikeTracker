import Foundation
import CoreLocation

struct StatisticsViewModel {
    let hike: HikeRecord

    /// 每公里配速数组（分钟/公里）
    var pacePerKm: [(km: Double, pace: Double)] {
        guard hike.locations.count >= 2 else { return [] }
        var segments: [(km: Double, pace: Double)] = []
        var accumulatedDistance: Double = 0
        var segmentStartIndex = 0

        for i in 1..<hike.locations.count {
            let prev = hike.locations[i - 1]
            let curr = hike.locations[i]
            let coord1 = CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude)
            let coord2 = CLLocationCoordinate2D(latitude: curr.latitude, longitude: curr.longitude)
            let loc1 = CLLocation(coordinate: coord1, altitude: prev.altitude, horizontalAccuracy: prev.horizontalAccuracy, verticalAccuracy: 0, timestamp: prev.timestamp)
            let loc2 = CLLocation(coordinate: coord2, altitude: curr.altitude, horizontalAccuracy: curr.horizontalAccuracy, verticalAccuracy: 0, timestamp: curr.timestamp)

            accumulatedDistance += loc1.distance(from: loc2)

            if accumulatedDistance >= 1000 {
                let timeInterval = curr.timestamp.timeIntervalSince(hike.locations[segmentStartIndex].timestamp)
                let pace = timeInterval / 60.0 // 分钟/公里
                let km = segments.count + 1
                segments.append((km: Double(km), pace: pace))
                accumulatedDistance = 0
                segmentStartIndex = i
            }
        }

        return segments
    }

    /// 海拔剖面数据（用于图表）
    var altitudeProfile: [(distance: Double, altitude: Double)] {
        guard hike.locations.count >= 1 else { return [] }
        var points: [(distance: Double, altitude: Double)] = []
        var accumulatedDistance: Double = 0

        for (i, location) in hike.locations.enumerated() {
            if i == 0 {
                points.append((distance: 0, altitude: location.altitude))
                continue
            }
            let prev = hike.locations[i - 1]
            let coord1 = CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude)
            let coord2 = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            let loc1 = CLLocation(coordinate: coord1, altitude: prev.altitude, horizontalAccuracy: prev.horizontalAccuracy, verticalAccuracy: 0, timestamp: prev.timestamp)
            let loc2 = CLLocation(coordinate: coord2, altitude: location.altitude, horizontalAccuracy: location.horizontalAccuracy, verticalAccuracy: 0, timestamp: location.timestamp)
            accumulatedDistance += loc1.distance(from: loc2)
            points.append((distance: accumulatedDistance, altitude: location.altitude))
        }

        return points
    }

    /// 所有徒步的汇总统计
    static func aggregateStats(for hikes: [HikeRecord]) -> (totalDistance: Double, totalDuration: TimeInterval, totalCount: Int) {
        let completed = hikes.filter { $0.endDate != nil }
        let totalDistance = completed.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = completed.reduce(0) { $0 + $1.duration }
        return (totalDistance, totalDuration, completed.count)
    }
}
