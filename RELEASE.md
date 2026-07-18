# FoxPhotoColor 发布清单

自动化验证(每轮迭代已跑):
- `scripts/harness.sh build` — Debug 模拟器构建(app + widget extension)
- `scripts/test-palette.sh` — 提色管线 19 断言(含 12MP 性能门槛 <2s),模拟器内执行
- `scripts/test-metadata.sh` — EXIF/GPS 解析自检(macOS)
- `scripts/release-check.sh` — Release 配置构建验证
- PrivacyInfo.xcprivacy 已就位(无追踪、无采集、无 required-reason API)

## 需要人工完成的步骤(需要 Apple Developer 账号 + 真机)

1. **签名**:Xcode → 两个 target(FoxPhotoColor / FoxPhotoColorWidgetExtension)
   设置你的 Team;App Group `group.me.sma1lboy.foxphotocolor` 需在
   developer.apple.com 注册并勾进两个 App ID。
2. **真机 QA**(模拟器无法覆盖的):
   - [ ] 实况照片:导入 → 卡片长按/点按播放 → 杀 app 重启 → 仍可播放
         (验证 content-identifier 配对,R8 审查修复的核心)
   - [ ] 触觉反馈:建卡 / 换色 / 甩删 / 撤销四个时刻
   - [ ] iCloud 优化存储照片离线导入 → 应弹「无法导入」错误
   - [ ] 桌面小组件:添加小/中两种,建卡后自动刷新
   - [ ] 关闭网络导入带 GPS 照片 → 标题保持默认,不卡片
3. **归档上传**:Product → Archive → Distribute → TestFlight。
4. **App Store 元数据**:截图可用 `scripts/harness.sh capture` 产物起稿;
   隐私问卷按「不收集任何数据」填写。
