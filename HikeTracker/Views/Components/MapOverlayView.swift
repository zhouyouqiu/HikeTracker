import SwiftUI
import MapKit

struct MapOverlayView: View {
    let polyline: MKPolyline?
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            if let polyline {
                MapPolyline(polyline)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }
}
