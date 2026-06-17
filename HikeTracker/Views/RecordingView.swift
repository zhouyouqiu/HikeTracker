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

            // 顶部：紧凑数据胶囊
            VStack {
                compactStatsPill
                    .padding(.top, 60)
                    .padding(.horizontal)
                Spacer()
            }

            // 底部：主按钮（+暂停时露出结束按钮）
            VStack {
                Spacer()
                bottomControls
                    .padding(.bottom, 40)
            }
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

    // MARK: - 顶部数据胶囊

    @ViewBuilder
    private var compactStatsPill: some View {
        let state = viewModel?.state ?? .idle
        HStack(spacing: 10) {
            Text(viewModel?.formattedDistance ?? "0 m")
            separator
            Text(viewModel?.formattedDuration ?? "00:00")
            separator
            Text(String(format: "%.0f m", viewModel?.currentAltitude ?? 0))

            if state != .idle {
                separator
                HStack(spacing: 4) {
                    Circle()
                        .fill(state == .recording ? .red : .orange)
                        .frame(width: 8, height: 8)
                        .pulse(if: state == .recording)
                    Text(state == .recording ? "录制中" : "已暂停")
                        .font(.caption.bold())
                        .foregroundStyle(state == .recording ? .red : .orange)
                }
            }
        }
        .font(.subheadline.bold())
        .monospacedDigit()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(radius: 3)
    }

    private var separator: some View {
        Text("·").foregroundStyle(.secondary).font(.subheadline)
    }

    // MARK: - 底部控制

    @ViewBuilder
    private var bottomControls: some View {
        let state = viewModel?.state ?? .idle
        HStack(spacing: 28) {
            // 结束按钮：仅在暂停时出现
            if state == .paused {
                Button {
                    viewModel?.stopRecording()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.red, in: Circle())
                        .shadow(radius: 4)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // 主按钮：状态变形
            Button {
                primaryAction(for: state)
            } label: {
                primaryButtonLabel(for: state)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    private func primaryAction(for state: RecordingState) {
        guard let vm = viewModel else { return }
        switch state {
        case .idle:
            vm.startRecording()
        case .recording:
            vm.pauseRecording()
        case .paused:
            vm.resumeRecording()
        }
    }

    @ViewBuilder
    private func primaryButtonLabel(for state: RecordingState) -> some View {
        let (icon, color, label): (String, Color, String) = {
            switch state {
            case .idle:     return ("play.fill", .green, "开始")
            case .recording:return ("pause.fill", .orange, "暂停")
            case .paused:   return ("play.fill", .green, "继续")
            }
        }()
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(color, in: Circle())
                .shadow(radius: 5)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers

    private var currentPolyline: MKPolyline? {
        guard let vm = viewModel, !vm.trackedLocations.isEmpty else { return nil }
        let converted = CoordinateConverter.wgs84ToGcj02(vm.trackedLocations)
        let simplified = CoordinateConverter.simplify(converted, epsilon: 10.0)
        let smoothed = CoordinateConverter.smoothPath(simplified, segments: 10)
        return MKPolyline(coordinates: smoothed, count: smoothed.count)
    }

    private func checkLocationPermission() {
        if !locationManager.isAuthorized {
            locationManager.requestPermission()
        }
    }
}

private struct NoOpModifier: ViewModifier {
    func body(content: Content) -> Content { content }
}

extension View {
    func pulseAnimation() -> some View {
        self.modifier(PulseEffect())
    }

    @ViewBuilder
    func pulse(if condition: Bool) -> some View {
        if condition {
            self.modifier(PulseEffect())
        } else {
            self
        }
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
