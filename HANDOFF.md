# FoxPhotoColor — Handoff

> 2026-07-17 晚。从空目录到功能完整的 iOS 色卡 app,17 commits,R1-R12 全部交付 + 卡片化视觉重构。本文档是接手的唯一入口;更细的约定见 `CLAUDE.md`,发布步骤见 `RELEASE.md`。

## 这是什么

复刻 App Store 上 PhotoColors(Haibin Wang)的 SwiftUI iOS app:选照片(含 Live Photo)→ k-means 提取主色 → 生成极简色卡海报。参考截图在 `~/Downloads/IMG_2504-2507.PNG`(整体)和 `IMG_2530-2533.PNG`(卡片结构特写,**布局真相源**)。设计规范:`.claude/skills/apple-design/SKILL.md`(用户指定的 emilkowalski apple-design skill,弹簧/手势/材质/排版全按它)。

## 当前功能(全部可用,模拟器验证过)

- 导入:PhotosPicker 免权限;EXIF 拍摄时间做卡片时间,GPS → CLGeocoder 自动命名(兴趣点→街区→城市回退,查到后动画淡入,不覆盖用户改名/换色)
- 海报:内嵌圆角卡片(20pt continuous)浮在放射渐变画布上(`CanvasBackground`:topLeading 亮→卡片色→底暗),照片贴满卡片宽、底边即卡片底边、被圆角裁切;标题 letterspaced 单行缩放居中在色块区;状态栏隐藏;空状态无顶栏
- 换色:点按卡片色块区循环调色板(`cycleColor`,替代旧色点行),重推背景+可读 accent(感知亮度差 ≥0.28 保证)
- Live Photo:配对视频持久化(**必须存原始字节**,见"坑"),卡上点按/长按播放,material 角标
- 手势:横滑翻卡;上滑删卡(1:1 跟踪、轴锁定、rubber-band、动量投射、速度交接弹簧)+ 5s 撤销 toast(无确认框,到期才删文件)
- 其他:网格总览、导出面板(手机全屏/4:5、调色板条、实时预览)、桌面小组件(App Group 快照)、触觉(4 个提交时刻)、zh/en(中文真相源)、Reduce Motion、VoiceOver、状态栏/顶栏随卡色翻转

## 架构(约 1600 行,无依赖)

```
FoxPhotoColor/           # app target(pbxproj 文件夹同步,新文件自动入 target)
  App/FoxPhotoColorApp   # 入口;种子在 HomeView.onAppear(必须先于 QA 钩子)
  Models/ColorCard       # RGBAColor(Codable, hsb, luminance, outerBackground)
  Models/CardStore       # @MainActor;JSON+文件持久化、NSCache 三级(display/thumb/live)、
                         #   软删除+撤销、孤儿清扫、widget 快照发布
  Color/PaletteExtractor # 确定性 k-means(亮度分位数初始化)→ muted 背景 + 可读 accent
  Support/PhotoMetadata  # EXIF/GPS 直读图片数据;CLGeocoder
  Views/                 # HomeView(手势/顶栏/alert 集中地)、CardView(海报卡)、
                         #   EmptyState、Grid、ExportOptions、Settings、ShareSheet
FoxPhotoColorWidget/     # widget target;读 App Group 的 widget-card.json + thumb
Config/*.entitlements    # App Group: group.me.sma1lboy.foxphotocolor
scripts/harness.sh       # build/run/capture/logs/reset(唯一构建入口)
scripts/test-palette.sh  # 19 断言,编成 iOS sim 二进制用 simctl spawn 跑
scripts/test-metadata.sh # EXIF 解析自检(macOS 直跑)
scripts/release-check.sh # Release 配置构建门
```

数据:`Documents/FoxPhotoColor/{cards.json + 原始图片 + .mov}`;widget 快照在 App Group 容器。

## 工具链(⚠️ 最大的坑)

- **只能用 `/Applications/Xcode.app`(16.2)构建**——本机唯一模拟器 runtime 是 iOS 18.2,26.4/16.4 都报 destination 错。`harness.sh` 已固定 `DEVELOPER_DIR`,别改。
- 模拟器:iPhone 16 Pro `A73B9E6D-4B12-4910-A15B-DA07C7657913`。
- **不要加 `CODE_SIGNING_ALLOWED=NO`**:App Group 靠模拟器 ad-hoc 签名嵌 entitlements。
- SourceKit 单文件诊断(No such module UIKit 等)全是无工程上下文噪音,以 harness build 为准。

## 其他已踩过的坑(都修了,别退回去)

1. **Live Photo 重启后配对**:落盘必须存 picker 原始字节(HEIC/JPEG 魔数嗅探),`jpegData` 重编码会剥掉 Apple content identifier → `PHLivePhoto.request` 永远失败。
2. corrupt cards.json 先移到 `.corrupt` 再继续,绝不静默覆盖;persist/导入失败都有用户可见 alert。
3. geocode 回填只 re-fetch 后改 title,防止覆盖查询期间的换色(全量 struct 回写竞态)。
4. TabView 删卡前必须先重指 selection;软删除期间 writeData 完成要更新 pendingDelete 副本。
5. QA 钩子(见下)在 onAppear 执行,种子必须在它之前跑。

## 怎么自己验证(不需要人点模拟器)

```bash
scripts/harness.sh all --seed        # build+装+种子启动+截图 → 用 Read 看图
scripts/test-palette.sh              # 提色管线 19 断言(含 12MP <2s 性能门)
scripts/test-metadata.sh             # EXIF/GPS 解析
scripts/release-check.sh             # Release 构建
```

QA 钩子(`SIMCTL_CHILD_` 前缀注入):`FPC_SEED=1` 种 3 卡;`FPC_SELECT=<i>` 跳卡;`FPC_RECOLOR=<i>:<j>` 走真实换色路径;`FPC_DELETE=<i>` 触发删除+toast;`FPC_EXPORT=1` 开导出面板;`FPC_GRID=1` 开网格。真照片:`xcrun simctl addmedia <udid> <文件>`。

## 流程约定

- commit 无任何 AI 署名;每轮迭代 = 实现 → 截图自验 → (重大改动)Workflow 对抗审查 → 修复 → commit → 勾 backlog。
- 三轮审查经验:报告的问题约一半是误报,**对抗验证环节必须保留**;confirmed 的 25+ 个都值得修。
- 用户开着 /loop(40 分钟/轮,ScheduleWakeup 2400s 自续)+ /goal(完成后继续迭代)。

## 下一步(backlog 见 CLAUDE.md 底部)

- R13:widget 点击深链到对应卡片(URL scheme 需给 app target 挂 partial Info.plist 加 CFBundleURLTypes)+ 锁屏小组件(accessoryRectangular)。深链可用 `simctl openurl` headless 验证。
- R14 设置扩充 / R15 iPad / R16 CloudKit。
- 需要用户才能做的:真机 Live Photo 全链路 QA、TestFlight(见 RELEASE.md,需要 Apple Developer 账号 + 注册 App Group)。
