import SwiftUI
import MapKit

struct MapOverlayView: View {
    let polyline: MKPolyline?
    var ghostPolyline: MKPolyline? = nil
    var currentPosition: CLLocationCoordinate2D? = nil
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if let ghostPolyline {
                MapPolyline(ghostPolyline)
                    .stroke(.gray.opacity(0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }

            if let polyline {
                MapPolyline(polyline)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            if let currentPosition {
                Annotation("", coordinate: currentPosition) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(.blue)
                            .frame(width: 10, height: 10)
                    }
                    .shadow(radius: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }
}
