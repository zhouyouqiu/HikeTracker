# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

iOS 徒步轨迹记录应用，SwiftUI + MapKit + CoreLocation + SwiftData 构建。真机运行（GPS 需真机）。

## 构建与测试

项目通过 Xcode 工程（`HikeTracker.xcodeproj`）管理，scheme 名为 `HikeTracker`，Bundle ID 仅在真机/模拟器构建时需要。

```bash
# 构建
xcodebuild -project HikeTracker.xcodeproj -scheme HikeTracker -sdk iphonesimulator build

# 运行全部测试（Swift Testing）
xcodebuild -project HikeTracker.xcodeproj -scheme HikeTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test

# 运行单个测试（Swift Testing 用 TestID，格式：StructName/methodName）
xcodebuild ... test -only-testing:HikeTrackerTests/RecordingViewModelTests/testFullRecordingFlow
```

注意：测试使用 **Swift Testing**（`import Testing`、`@Test`、`#expect`），不是 XCTest。测试位于 `HikeTrackerTests/RecordingViewModelTests.swift`，端到端覆盖录制→持久化流程，依赖 `ModelConfiguration(isStoredInMemoryOnly: true)` 内存库。

## 架构

标准 MVVM：`HikeTrackerApp`（SwiftData ModelContainer 注入）→ `ContentView`（TabView 三栏）→ 各 Tab 的 View + ViewModel。

**状态管理用 `@Observable`（非 Combine）**：`LocationManager`、`RecordingViewModel` 都是 `@Observable final class`，View 通过 `@State` / `@Environment` 持有。

**数据流（录制时）**：
1. `LocationManager`（CLLocationManager delegate）收到原始 GPS 点
2. `LocationManager.didUpdateLocations` 过滤：水平精度 `>20m` 或 `<=0` 丢弃；`speed >=15` 或 `<0` 丢弃
3. 通过的点位经 `onLocationUpdate` 回调给 `RecordingViewModel.addLocation`
4. `addLocation` 再过滤：距上一点 `<5m` 视为漂移；若距上一点 `<15m` 且方向偏转 `>90°` 视为抖动
5. 通过则累加距离/海拔，append 到 `trackedLocations`
6. `stopRecording` 时把 `trackedLocations` 转成 `LocationPoint` 数组写入 `HikeRecord`，持久化到 SwiftData

⚠️ 过滤阈值修改要谨慎：最近一次 bug（commit 68b9cc6）就是精度阈值过严导致轨迹完全不记录。`LocationManager` 的 20m 阈值和 `addLocation` 的 5m 阈值是两道独立闸门。

## 坐标转换（中国地图偏移）

`Services/CoordinateConverter.swift` 实现 WGS-84 → GCJ-02 转换 + Douglas-Peucker 轨迹简化。**这是为了在中国地图上正确显示**（国内 MapKit 显示需要 GCJ-02 坐标）。`isInChina()` 判断坐标是否在国境内，境外直接返回原坐标。渲染地图前需调用此转换，存储仍用原始 WGS-84。

## 模型

`Models/HikeRecord.swift` 定义两个 `@Model`：
- `HikeRecord`：一次徒步，`@Relationship(deleteRule: .cascade)` 关联 `LocationPoint` 数组
- `LocationPoint`：单个 GPS 点

`HikeRecord` 内置格式化计算属性（`formattedDistance`、`formattedDuration`、`formattedPace`、`averagePace`、`averageSpeed`），UI 直接读取。

## 关键文件

```
HikeTracker/HikeTracker/
├── HikeTrackerApp.swift          # @main，ModelContainer 配置（isStoredInMemoryOnly: false）
├── ContentView.swift             # TabView 三栏入口（记录/历史/统计）
├── Info.plist                    # NSLocationWhenInUseUsageDescription、NSLocationAlwaysUsageDescription、UIBackgroundModes=location
├── Models/HikeRecord.swift       # SwiftData 模型 + 格式化计算属性
├── Services/
│   ├── LocationManager.swift     # CoreLocation 封装（@Observable，回调式）
│   └── CoordinateConverter.swift # WGS-84↔GCJ-02 + Douglas-Peucker 简化
├── ViewModels/
│   ├── RecordingViewModel.swift  # RecordingState(idle/recording/paused)、过滤、距离海拔累加
│   └── StatisticsViewModel.swift # 配速分段、海拔剖面、月度汇总
└── Views/                        # SwiftUI 视图 + Components/(MapOverlayView, StatCard)
```

## Xcode 工程配置要点

- 新建项目时：Interface=SwiftUI，Storage=None（SwiftData 代码配置），Testing=None
- **必须**在 Signing & Capabilities 添加 Background Modes → Location updates
- `UIBackgroundModes` 需含 `location`，否则后台无法持续定位
