# FoxPhotoColor

iOS (SwiftUI, iOS 17+) 色卡生成 app,参考 PhotoColors:选照片 → k-means 提取主色 → 生成极简色卡海报(自适应背景 + letterspaced 标题 + 时间 + 居中照片),支持重命名、导出分享、多卡横滑。

## 设计

- 设计规范:`.claude/skills/apple-design/SKILL.md`(弹簧动画默认 critically damped `response 0.3–0.5, damping 1.0`;按压反馈用 `PressableButtonStyle`;背景色切换用 spring 过渡)。
- 参考截图:`~/Downloads/IMG_2504-2507.PNG` + 特写 `IMG_2530-2533.PNG`(布局与配色的真相源)。
- 布局基准(2530-2533 实测):**海报是内嵌圆角卡片**——外层画布 = 以卡片色为中点的放射渐变(`CanvasBackground`:topLeading 亮 24% → 卡片色 → 底部暗 14%);卡片顶在屏高 17%、左右 15pt、圆角 20 continuous;标题区高 = 屏高 24.9%,标题居中其间;照片贴满卡片宽度、自然宽高比、底边即卡片底边(被圆角裁切),下限屏高 22%、上限到屏底留 15pt。顶栏:品牌字 21pt bold 左 16pt,右侧 46pt material 圆钮。状态栏隐藏。空状态页无顶栏、无卡片,全屏 CanvasBackground 绿。点按卡片色块区循环调色板换背景(替代旧色点行)。

## 构建 & 调试 harness(重要:全部自助,不需要人工点模拟器)

```bash
scripts/harness.sh build          # xcodebuild -> build/
scripts/harness.sh run --seed     # 装进 iPhone 16 Pro 模拟器并以种子数据启动
scripts/harness.sh capture NAME   # 截图到 artifacts/NAME.png,然后用 Read 工具看图验证
scripts/harness.sh logs           # 最近 2 分钟 app 日志
scripts/harness.sh reset          # 卸载(清数据),用于重测空状态
scripts/harness.sh all --seed     # build+run+capture 一条龙
```

- **种子模式**:`FPC_SEED=1`(经 `SIMCTL_CHILD_FPC_SEED` 注入)且卡片为空时,`SampleSeed` 会在启动时生成 3 张合成"照片"(晚霞/蓝天/森林)并走完整提取管线建卡,从而不碰 PhotosPicker 也能截到卡片页。
- 验证循环:改代码 → `all --seed` → Read 截图 → 对照参考图调整。空状态验证:`reset` 后 `run`(不带 --seed)。
- 真实照片测试:`xcrun simctl addmedia <udid> <图片路径>` 往模拟器相册塞图,但点击 PhotosPicker 需要 UI 自动化,暂用种子模式替代。

## 约定

- i18n:所有用户可见文案走 `Localizable.xcstrings`(sourceLanguage zh-Hans,en 必须同步补齐);Swift 里用 `Text("key")` / `String(localized:)`。品牌名 FoxPhotoColor 用 `Text(verbatim:)` 豁免。
- 工程文件:手写 pbxproj(objectVersion 77,PBXFileSystemSynchronizedRootGroup)—— `FoxPhotoColor/` 下新增文件自动入 target,**不需要**改 pbxproj。
- SourceKit 单文件诊断(No such module UIKit 等)是无工程上下文的噪音,以 `scripts/harness.sh build` 为准。
- 持久化:Documents/FoxPhotoColor/{cards.json + *.jpg},无数据库。

## 迭代 backlog(按轮次推进,完成即勾)

- [x] R1: 工程脚手架 + 提色管线 + 卡片/空状态/设置/导出 + harness + i18n
- [x] R2: 视觉对齐参考图 + app 图标 + 状态栏适配 + 审查修复(数据丢失防护/NSCache 降采样/accent 感知亮度/Reduce Motion/删卡 selection)
- [x] R3: EXIF/GPS 自动命名(免相册权限直读图片数据)+ CLGeocoder 反向地理编码,拍摄时间做卡片时间
- [x] R4: 卡片底部调色板圆点(44pt 命中区,VoiceOver 逐点标签),点选换背景 + accent 自动重配,FPC_RECOLOR 钩子验证
- [x] R5: 上滑删除手势(轴锁定 1:1 跟踪、rubber-band、动量投射决定提交、速度交接进弹簧)+ 5s 撤销 toast(免确认框,到期才真删文件)
- [x] R6: 导出样式面板(实时预览、手机全屏/4:5、可选调色板条)
- [x] R7: 模拟器内单元测试 scripts/test-palette.sh(18 断言:确定性/感知亮度差/退化输入/JSON 精确往返/rederive)+ test-metadata.sh

**↑ MVP 完成(R1-R7 全勾,10 commits)。继续迭代:**

- [x] R8: Live Photo 支持(picker 双载 PHLivePhoto,配对视频经 PHAssetResource 持久化,卡上长按播放 + livephoto 角标;真机 E2E 待 R12)
- [x] R9: 网格总览(双列迷你海报,点击跳卡,FPC_GRID 钩子)
- [x] R11a: 触觉反馈(建卡/换色/甩删/撤销四个提交时刻)
- [x] R8/R9 审查加固:原始字节持久化(保 content identifier,重启后 Live Photo 可重配对)、视频后置加载、标题区/照片区手势分权、badge material 底、孤儿文件清扫、360px 网格缩略图缓存
- [x] R10: WidgetKit 小组件(小/中两档,App Group 快照共享,persist 即刷新;pbxproj 手写 extension target)
- [x] R11b: 性能门槛(12MP 提取 0.05s,基准断言 <2s 进测试)
- [x] R12: 发布就绪(PrivacyInfo.xcprivacy、Release 构建门、RELEASE.md)——真机 QA 与 TestFlight 上传需用户的 Apple Developer 账号,清单已备好

**↑ R1-R12 全部完成(15 commits)。项目按原始规划交付。继续迭代方向(R13+):**

- [x] R13: 锁屏小组件(accessoryRectangular,vibrant 材质纯文字档)+ widget 深链——AppInfo.plist(根目录,GENERATE_INFOPLIST_FILE 合并;放 FoxPhotoColor/ 内会被同步组打成资源冲突)注册 foxphotocolor:// scheme,快照带卡片 id,widgetURL → onOpenURL 选卡;E2E:simctl openurl + osascript 点系统确认框(真实 widget 点击无此框),验证跳到目标卡
- [ ] R14: 设置页扩充(时间格式 12/24h、默认导出比例、清除全部数据)
- [x] R15: iPad 适配第一版——TARGETED_DEVICE_FAMILY "1,2"(4 configs);海报画布 iPad 限宽 560pt 居中(保手机比例不拉伸),手势命中同步 canvasSize + inScreenSpace 偏移;Classic 的冻结布局要显式传 screenSize: canvasSize(默认 UIScreen 会漏过容器限宽)。iPad Air 11 实测 moment/classic ✓。横屏:app 竖屏锁定 + INFOPLIST_KEY_UIRequiresFullScreen = YES(iPad 多任务豁免,App Store 合规);sheet 默认样式可用
- [ ] R16: CloudKit 同步(多设备色卡库)
- [x] R17: AI 诗意标题(Support/AITitle.swift 走本地 CPA http://127.0.0.1:8317 /v1/messages,兜底链 GPS 地名 → AI → 默认;env: FPC_AI_BASE_URL/FPC_AI_KEY/FPC_AI_MODEL)
- [x] R18a: 模式基础设施 + Moment Card(CardMode/fpc.mode、MomentCardView 拍立得卡 + 相机 EXIF 元数据区 + 呼吸 blob 动效、设置页模式选择已接线、诗意标题优先开关 fpc.alwaysPoeticTitle、FPC_MODE 钩子;seed 卡带演示相机数据)
- [x] R18b: 全部模式完成——Bubble Stamp(全出血照片 + 调色板呼吸气泡漂浮 + 玻璃标题章)、Spectrum Wallpaper(调色板亮→暗全屏渐变 + 底部签名)、Magic Journal(手账页:日期头 + 斜贴白边照片 + 衬线斜体标题 + 色点行);设置选模式即关 sheet 回主页(参考 app 行为)
- [x] R19: 导出跟随模式——PosterView 按 fpc.mode 渲染对应模式视图(预览+分享一致),品牌 chrome 置顶层盖全出血模式,Bubble 导出用平面章替代 material,Moment/Journal 在 4:5 下照片高度自适应防溢出;网格缩略图保持模式无关的导航样式(有意为之)
- [x] R20: 设置全部接线——ColorCard 存 captureDate,CardTime 渲染时按 fpc.use24HourTime 实时格式化(五个模式视图统一,老卡回退存量 timeText);fpc.livePhotoEnabled 门控 Live Photo 加载;fpc.defaultExportAspect 作为导出面板初始比例;设置页三处「即将生效」移除
- [x] R21: AI 标题健壮性——请求失败重试 1 次;启动时对停在默认标题的卡补一次 AI 命名(E2E:断 CPA 导入→SOMEWHERE,恢复重启→自动补名);提示词随系统语言出中/英文标题;widget 快照时间跟随 12/24h 设置。注意:simctl `defaults write` 写的是模拟器用户级偏好,uninstall 不清,测试后要 `defaults delete`
- [x] R22: scripts/check-i18n.sh(双目录完整性 + 引用存在性 + 孤儿键检测,当前 78 键全绿;修了 posterButton( 误匹配 Button( 的正则);Bubble 气泡布局移出 30fps 闭包、收紧抖动、y 硬 clamp 到 0.10-0.72 屏高防边缘裁切
- [x] R23: 设置页「清除全部数据」——CardStore.removeAll()(清缓存+删文件+persist+widget 快照重置),红色危险行 + confirmationDialog 双确认,FPC_CLEAR 钩子 E2E(cards.json 归零、文件全删、回空状态)。R14 三项(时间格式/导出比例/清数据)全部完成
- [x] R24: 气泡拖拽——NormalizedPoint 归一化坐标存 ColorCard.bubblePositions([Int:点],老卡解码兼容),拖拽 1:1 跟手 + 按住放大/停止呼吸 + 落点回弹,松手持久化;上滑删除手势对气泡命中区(≥44pt)让路;FPC_BUBBLE 钩子验证存取。两个关键修复:① TimelineView 嵌套在 ZStack 里会让子视图 .position 坐标空间漂移——改为 TimelineView 包整个扁平 ZStack(photo/气泡/stamp 同空间)后像素级对齐;② 气泡与照片同源色导致伪装隐形——加 1.2pt 白色 hairline rim
- [x] R25: 质量收口——bubble 模式 CPU 实测 ~5%(30fps 重绘无需优化);导出预览验证携带气泡存储位置(等比例正确);修 test-palette.sh 编译清单(补 CameraInfo.swift,CameraInfo 拆文件后 ColorCard 的 Codable 合成断了),18 断言全过 + metadata 自检 OK;五模式回归全家福 artifacts/gallery-*.png
- [x] R26: 四个新模式视图的 VoiceOver 补课——装饰元素(呼吸 blob、漂浮气泡、调色板点)accessibilityHidden;标题带「点按重命名」提示(新键 card.rename.a11y);可点卡面带换色提示(复用 card.recolor.a11y);Bubble 标题章 combine 成单个可读元素
- [ ] R27: 真机 QA + TestFlight(需用户 Apple 账号);未提交改动分批 commit(待用户指示)
- [x] R28: 模式命名对齐参考 app——classic→moment(时刻卡=极简海报)、moment→bubble(气泡贴纸=拍立得+相机参数)、自创漂浮气泡模式改名 floating;视图文件同步改名(MomentCardView→BubbleStampView、原 BubbleStampView→FloatingBubblesView);旧 fpc.mode 值回退默认 moment
- [x] R29: Vitreous Palette 琉璃色卡模式(参考 IMG_2547)——大圆角照片卡(无标题区)+ ultraThinMaterial 玻璃面板 2×3 色圆 + 等宽 hex 标签,点色圆即换画布背景;导出走平面填充;列表中排第二
- [x] R30: Liquid Glass(fpcGlass 双门控:compiler>=6.2 + iOS 26 available;顶栏钮 .regular.interactive、Vitreous 面板 .clear 高透变体、Floating 章 .regular;Xcode 26.4 + iOS 26.4 sim 验证)+ per-card 模式(建卡盖章 card.mode,浏览/导出/手势用 effectiveMode,老卡跟随全局)。真机链:Xcode 26.4 + team 68562FABX7 + 无 App Group entitlements 覆盖(CLI 无法补 App ID 能力,widget 共享待 Xcode GUI 配)
