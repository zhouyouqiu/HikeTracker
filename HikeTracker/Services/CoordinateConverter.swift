import Foundation
import CoreLocation

/// WGS 84 → GCJ-02 坐标转换 + 轨迹简化
enum CoordinateConverter {

    private static let a = 6378245.0 // 长半轴
    private static let ee = 0.00669342162296594323 // 扁率

    // MARK: - 坐标转换

    /// 判断是否在中国境内
    static func isInChina(_ lat: Double, _ lon: Double) -> Bool {
        return lon >= 72.004 && lon <= 137.8347 && lat >= 0.8293 && lat <= 55.8271
    }

    /// WGS 84 → GCJ-02
    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        guard isInChina(latitude, longitude) else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var dLat = transformLat(x: longitude - 105.0, y: latitude - 35.0)
        var dLon = transformLon(x: longitude - 105.0, y: latitude - 35.0)

        let radLat = latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)

        return CLLocationCoordinate2D(latitude: latitude + dLat, longitude: longitude + dLon)
    }

    /// 批量转换 CLLocationCoordinate2D
    static func wgs84ToGcj02(_ coords: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        coords.map { wgs84ToGcj02(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// 批量转换 CLLocation
    static func wgs84ToGcj02(_ locations: [CLLocation]) -> [CLLocationCoordinate2D] {
        locations.map { wgs84ToGcj02(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }

    // MARK: - 轨迹简化（Douglas-Peucker）

    /// 简化坐标数组，epsilon 为最大允许偏差（米）
    static func simplify(_ coords: [CLLocationCoordinate2D], epsilon: Double = 10.0) -> [CLLocationCoordinate2D] {
        guard coords.count > 2 else { return coords }

        let first = coords.first!
        let last = coords.last!

        var maxDist = 0.0
        var maxIndex = 0

        for i in 1..<(coords.count - 1) {
            let dist = perpendicularDistance(coords[i], lineStart: first, lineEnd: last)
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left = simplify(Array(coords[0...maxIndex]), epsilon: epsilon)
            let right = simplify(Array(coords[maxIndex..<coords.count]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [first, last]
        }
    }

    /// 点到线段的垂直距离（米）
    private static func perpendicularDistance(_ point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let p = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let a = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let b = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)

        let lineLen = a.distance(from: b)
        if lineLen == 0 { return a.distance(from: p) }

        let px = CLLocation(latitude: point.latitude, longitude: lineStart.longitude).distance(from: a)
        let py = CLLocation(latitude: lineStart.latitude, longitude: point.longitude).distance(from: a)
        let ax = CLLocation(latitude: lineEnd.latitude, longitude: lineStart.longitude).distance(from: a)
        let ay = CLLocation(latitude: lineStart.latitude, longitude: lineEnd.longitude).distance(from: a)

        let t = max(0, min(1, ((px * ax) + (py * ay)) / (lineLen * lineLen)))

        let projLat = lineStart.latitude + t * (lineEnd.latitude - lineStart.latitude)
        let projLon = lineStart.longitude + t * (lineEnd.longitude - lineStart.longitude)
        let projection = CLLocation(latitude: projLat, longitude: projLon)

        return p.distance(from: projection)
    }

    // MARK: - Private

    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}
