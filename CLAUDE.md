# HikeTracker

iOS 徒步轨迹记录应用，使用 SwiftUI + MapKit + CoreLocation + SwiftData 构建。

## 项目结构

```
HikeTracker/HikeTracker/
├── HikeTrackerApp.swift          # App 入口，TabView 三栏（记录/历史/统计）
├── Info.plist                    # 位置权限 + 后台定位（UIBackgroundModes: location）
├── Models/
│   └── HikeRecord.swift          # SwiftData 数据模型（HikeRecord + LocationPoint）
├── Services/
│   └── LocationManager.swift     # CoreLocation 高精度定位服务（5m 过滤，20m 精度阈值）
├── ViewModels/
│   ├── RecordingViewModel.swift  # 录制状态管理（idle/recording/paused），轨迹距离/海拔计算
│   └── StatisticsViewModel.swift # 配速分段、海拔剖面、汇总统计计算
└── Views/
    ├── RecordingView.swift       # 主录制界面：全屏地图 + 实时轨迹 + 开始/暂停/停止控制
    ├── HikeDetailView.swift      # 徒步详情：轨迹回放 + 运动数据 + 配速/海拔图表（Swift Charts）
    ├── HistoryListView.swift     # 历史记录：按日期分组，滑动删除
    ├── StatisticsView.swift      # 数据统计：累计总览 + 月度里程柱状图 + 最近记录
    └── Components/
        ├── MapOverlayView.swift  # MapKit 地图 + MKPolyline 轨迹渲染
        └── StatCard.swift        # 统计卡片组件
```

## 需求

- GPS 实时轨迹记录，支持后台持续定位
- 地图渲染轨迹折线（MapKit + MKPolyline）
- 数据统计：距离、时长、配速、海拔（最高/最低/累计爬升/下降）
- 配速折线图（每公里分段配速）、海拔剖面图（Swift Charts）
- 历史记录管理（按日期分组、查看详情、删除）
- 累计统计（总里程、总次数、月度图表）

## 技术要点

- 定位精度：`kCLLocationAccuracyBestForNavigation`，`distanceFilter = 5m`，水平精度 > 20m 的点过滤
- 轨迹点间距 < 2m 视为漂移过滤
- SwiftData 持久化，`@Model` 宏定义模型，`.modelContainer(for:)` 配置
- Xcode 新建项目时 Interface 选 SwiftUI，Storage 选 None（SwiftData 通过代码配置），Testing 选 None
- Info.plist 需配置 `NSLocationWhenInUseUsageDescription`、`NSLocationAlwaysUsageDescription`、`UIBackgroundModes`
- 需在 Signing & Capabilities 中添加 Background Modes → Location updates

## 构建运行

1. Xcode → File → New → Project → App，Product Name 填 `HikeTracker`
2. 将 `HikeTracker/HikeTracker/` 下文件拖入项目替换
3. 添加 Background Modes capability（Location updates）
4. 真机运行（GPS 定位需要真机）
