# HikeTracker

> 一款 iOS 徒步轨迹记录与回放 App —— 把每一段山路完整地留下来。

HikeTracker 是一个用 SwiftUI + MapKit + CoreLocation + SwiftData 构建的轻量徒步记录应用。它在你徒步时持续记录 GPS 轨迹，绘制平滑的路线，统计距离、配速、海拔等运动数据，并在事后让你按时间顺序回放整段行程。所有数据仅保存在你的设备本地，无需联网，不向任何服务器上传。

## 功能特性

- **实时轨迹记录** —— 高精度 GPS 持续定位，支持后台记录，息屏也能继续追踪
- **平滑路线绘制** —— MapKit 折线 + Catmull-Rom 样条平滑，告别锯齿感
- **完整运动数据** —— 距离、时长、平均配速、平均速度、海拔（最高 / 最低 / 累计爬升 / 累计下降）
- **数据可视化** —— 分段配速折线图（每公里）、海拔剖面图（Swift Charts）
- **历史记录管理** —— 按日期分组浏览、查看详情、滑动删除
- **累计统计** —— 总里程、总次数、月度里程柱状图
- **轨迹回放** —— 详情页一键回放，路线按时间顺序逐段生长，带 ease-in-out 缓动，重温整段徒步
- **中国地图适配** —— 自动 WGS-84 → GCJ-02 坐标转换，国内地图显示不偏移

## 技术栈

| 领域 | 技术 |
|---|---|
| UI 框架 | SwiftUI |
| 地图 | MapKit（MKPolyline 渲染） |
| 定位 | CoreLocation（高精度 + 后台定位） |
| 持久化 | SwiftData（`@Model` + `ModelContainer`） |
| 图表 | Swift Charts |
| 测试 | Swift Testing |

最低系统：**iOS 18.6+**  
Swift：5.0

## 项目结构

```
HikeTracker/
├── HikeTrackerApp.swift          # App 入口，SwiftData 容器配置
├── ContentView.swift             # TabView 三栏（记录 / 历史 / 统计）
├── Models/
│   └── HikeRecord.swift          # SwiftData 模型（HikeRecord + LocationPoint）
├── Services/
│   ├── LocationManager.swift     # CoreLocation 高精度定位封装
│   └── CoordinateConverter.swift # WGS-84↔GCJ-02 转换 + Douglas-Peucker 抽稀 + 样条平滑
├── ViewModels/
│   ├── RecordingViewModel.swift  # 录制状态机、轨迹过滤、距离/海拔累加
│   └── StatisticsViewModel.swift # 配速分段、海拔剖面、汇总统计
└── Views/
    ├── RecordingView.swift       # 录制页：全屏地图 + 顶部数据胶囊 + 底部主控按钮
    ├── HikeDetailView.swift      # 详情页：轨迹回放 + 运动数据 + 配速/海拔图表
    ├── HistoryListView.swift     # 历史列表（按日期分组、滑动删除）
    ├── StatisticsView.swift      # 累计统计 + 月度柱状图
    └── Components/
        ├── MapOverlayView.swift  # 地图 + 折线渲染（支持回放进度线 / 移动点）
        └── StatCard.swift        # 统计卡片组件
```

## 隐私说明

HikeTracker 是一个**完全离线**的应用：

- 所有轨迹与统计数据仅保存在你设备的 SwiftData 本地数据库中
- 不内置任何网络请求，不连接任何服务器，不上传任何位置信息
- 位置权限仅用于记录你的徒步轨迹，绝不会用于其他用途

## 构建与运行

### 环境要求

- Xcode 26+（含 iOS 26 SDK）
- 一台运行 iOS 18.6 或更高版本的 iPhone（GPS 记录需要真机）

### 步骤

1. 克隆仓库：

   ```bash
   git clone https://github.com/zhouyouqiu/HikeTracker.git
   cd HikeTracker
   ```

2. 用 Xcode 打开 `HikeTracker.xcodeproj`。
3. 在项目设置里配置你自己的 Signing & Capabilities（Developer 账号即可）。
4. **添加 Background Modes capability** → 勾选 **Location updates**（后台持续定位必需）。
5. 选择真机，运行。

> 首次运行时 App 会请求位置权限，请选择「使用 App 期间」并按系统提示授权「始终」，以便后台记录。

## 测试

测试基于 Swift Testing：

```bash
xcodebuild -project HikeTracker.xcodeproj -scheme HikeTracker \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## 截图

> 待补充

## 开源协议

本项目基于 [MIT License](LICENSE) 开源，欢迎学习、使用、二次开发。

Copyright (c) 2026 youqiu.zhou
