# 项目长期记忆

## 版本号与构建规范
- 版本号定义在 `pubspec.yaml`（例如 `version: 0.1.5+7`，格式 `versionName+versionCode`）。
- 自定义更新弹窗展示版本在 `version.json`（`version`、`build`、`date`）。
- 每次发布必须同时更新 `pubspec.yaml` 和 `version.json`。
- 安卓 versionCode 必须递增，否则无法覆盖安装。

## 依赖与 Android 构建经验
- `file_picker` 大版本升级会改 API：`11.x` 移除了 `FilePicker.platform.pickFiles(...)`，改为静态方法 `FilePicker.pickFiles(...)`。
- 当 CI 报 `checkReleaseAarMetadata` 失败并提示插件需要更高 Android API 时，先检查 `android/app/build.gradle.kts` 的 `compileSdk`/`targetSdk`；若插件包自身 AAR 用旧 SDK 编译，还需升级对应 pub 依赖。
- 本项目 `compileSdk`/`targetSdk` 已固定为 36（`android/app/build.gradle.kts`），以兼容 `file_picker 11.x` 及其依赖。

## 代码约定
- 主题/颜色使用 `AppBgTheme`、`AppDark`、`AppThemeMode.isLight` 做自适应，不要硬编码 `Colors.white`/`Colors.black`。
- 状态持久化使用 `Storage` 服务，导出导入/去重逻辑放在 `Storage.bulkAdd`。
