# FoxPhotoColor

iOS (SwiftUI, iOS 17+) 色卡生成 app,参考 PhotoColors:选照片 → k-means 提取主色 → 生成极简色卡海报(自适应背景 + letterspaced 标题 + 时间 + 居中照片),支持重命名、导出分享、多卡横滑。

## 设计

- 设计规范:`.claude/skills/apple-design/SKILL.md`(弹簧动画默认 critically damped `response 0.3–0.5, damping 1.0`;按压反馈用 `PressableButtonStyle`;背景色切换用 spring 过渡)。
- 参考截图:`~/Downloads/IMG_2504-2507.PNG`(App Store 截图,布局与配色的真相源)。
- 布局基准:标题块占屏高上部 34% 居中,照片 `scaledToFit` 最大高 42%,左右留白 24pt。

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
- [ ] R3: 从 PHAsset 读取拍摄时间/地点自动命名(反向地理编码)
- [ ] R4: 调色板 UI(卡片下滑出 swatches,可选任一色作背景)
- [ ] R5: 卡片切换/删除的流体动画与手势(velocity handoff、rubber-band)
- [ ] R6: 导出样式选项(含/不含调色板条、比例 4:5/9:16)
- [ ] R7: 单元测试(PaletteExtractor 确定性、CardStore 持久化)
