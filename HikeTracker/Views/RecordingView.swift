import SwiftUI
import SwiftData
import MapKit

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var locationManager = LocationManager()
    @State private var viewModel: RecordingViewModel?
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            MapOverlayView(
                polyline: currentPolyline,
                cameraPosition: $cameraPosition
            )
            .ignoresSafeArea()

            // 顶部状态栏
            VStack {
                recordingStatusBar
                    .padding(.top, 60)
                    .padding(.horizontal)
                Spacer()
            }

            // 底部控制面板
            VStack(spacing: 20) {
                statsPanel
                controlButtons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            if viewModel == nil {
                let vm = RecordingViewModel(locationManager: locationManager)
                vm.configure(modelContext: modelContext)
                viewModel = vm
            }
            checkLocationPermission()
        }
        .alert("需要位置权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在系统设置中允许 HikeTracker 访问您的位置")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var recordingStatusBar: some View {
        if let vm = viewModel, vm.state != .idle {
            HStack {
                if vm.state == .recording {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .pulseAnimation()
                    Text("录制中")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                    Spacer()
                    if vm.trackedLocations.count > 0 {
                        Text("\(vm.trackedLocations.count) 个轨迹点")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if vm.state == .paused {
                    Circle()
                        .fill(.orange)
                        .frame(width: 10, height: 10)
                    Text("已暂停")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                }
            }
            .padding(10)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var statsPanel: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "距离",
                value: viewModel?.formattedDistance ?? "0 m",
                icon: "figure.walk"
            )
            StatCard(
                title: "时长",
                value: viewModel?.formattedDuration ?? "00:00",
                icon: "clock"
            )
            StatCard(
                title: "海拔",
                value: String(format: "%.0f m", viewModel?.currentAltitude ?? 0),
                icon: "mountain.2"
            )
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 50) {
            // 开始/继续按钮
            Button {
                guard let vm = viewModel else { return }
                if vm.state == .idle || vm.state == .paused {
                    if vm.state == .idle {
                        vm.startRecording()
                    } else {
                        vm.resumeRecording()
                    }
                }
            } label: {
                Image(systemName: viewModel?.state == .idle || viewModel?.state == .paused ? "play.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(.green, in: Circle())
                    .shadow(radius: 4)
            }
            .opacity(viewModel?.state != .recording ? 1 : 0.3)
            .disabled(viewModel?.state == .recording)

            // 暂停按钮
            Button {
                viewModel?.pauseRecording()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(.orange, in: Circle())
                    .shadow(radius: 4)
            }
            .opacity(viewModel?.state == .recording ? 1 : 0.3)
            .disabled(viewModel?.state != .recording)

            // 停止按钮
            Button {
                viewModel?.stopRecording()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(.red, in: Circle())
                    .shadow(radius: 4)
            }
            .opacity(viewModel?.state == .recording || viewModel?.state == .paused ? 1 : 0.3)
            .disabled(viewModel?.state == .idle)
        }
    }

    // MARK: - Helpers

    private var currentPolyline: MKPolyline? {
        guard let vm = viewModel, !vm.trackedLocations.isEmpty else { return nil }
        let converted = CoordinateConverter.wgs84ToGcj02(vm.trackedLocations)
        let simplified = CoordinateConverter.simplify(converted, epsilon: 10.0)
        return MKPolyline(coordinates: simplified, count: simplified.count)
    }

    private var formattedDistance: String {
        guard let vm = viewModel else { return "0 m" }
        let dist = vm.currentDistance
        if dist >= 1000 {
            return String(format: "%.2f km", dist / 1000.0)
        }
        return String(format: "%.0f m", dist)
    }

    private var formattedDuration: String {
        guard let vm = viewModel else { return "00:00" }
        let hours = Int(vm.currentDuration) / 3600
        let minutes = (Int(vm.currentDuration) % 3600) / 60
        let seconds = Int(vm.currentDuration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func checkLocationPermission() {
        if !locationManager.isAuthorized {
            locationManager.requestPermission()
        }
    }
}

extension View {
    func pulseAnimation() -> some View {
        self.modifier(PulseEffect())
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

private extension RecordingViewModel {
    var formattedDistance: String {
        let dist = currentDistance
        if dist >= 1000 {
            return String(format: "%.2f km", dist / 1000.0)
        }
        return String(format: "%.0f m", dist)
    }

    var formattedDuration: String {
        let hours = Int(currentDuration) / 3600
        let minutes = (Int(currentDuration) % 3600) / 60
        let seconds = Int(currentDuration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
