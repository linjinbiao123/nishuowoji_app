# 项目长期记忆

## 版本号与构建规范
- 版本号定义在 `pubspec.yaml`（例如 `version: 0.1.5+7`，格式 `versionName+versionCode`）。
- 自定义更新弹窗展示版本在 `version.json`（`version`、`build`、`date`）。
- 每次发布必须同时更新 `pubspec.yaml` 和 `version.json`。
- 安卓 versionCode 必须递增，否则无法覆盖安装。

## 依赖与 Android 构建经验
- `file_picker 11.x` 存在严重问题，**不要使用**：11.0.0 因 Android 包漏加 `kotlin-android` 插件导致 Kotlin 源码未编译，`GeneratedPluginRegistrant.java` 找不到 `FilePickerPlugin`，CI 构建必失败；且其 API 也改了（`FilePicker.platform.pickFiles` → 静态 `FilePicker.pickFiles`）。**本项目固定使用 `file_picker: 10.3.10`**（10.x 用 `FilePicker.platform.pickFiles`）。
- 当 CI 报 `checkReleaseAarMetadata` 失败并提示插件需要更高 Android API 时，先检查 `android/app/build.gradle.kts` 的 `compileSdk`/`targetSdk`；若插件包自身 AAR 用旧 SDK 编译，还需升级对应 pub 依赖。
- 本项目 `compileSdk`/`targetSdk` 已固定为 36（`android/app/build.gradle.kts`）。

## 代码约定
- 主题/颜色使用 `AppBgTheme`、`AppDark`、`AppThemeMode.isLight` 做自适应，不要硬编码 `Colors.white`/`Colors.black`。
- 状态持久化使用 `Storage` 服务，导出导入/去重逻辑放在 `Storage.bulkAdd`。

## 多账户功能（2026-08-14 新增）
- 数据模型：`Account`（id/name/balance/icon），按账本独立存储在 `accounts_{ledgerId}`；默认只预置「微信」「支付宝」两个账户，无「银行卡」。
- `Record` 增加可选字段 `accountId`：null 表示不计入任何账户（正常记账），有值则保存时自动增减该账户余额（支出减、收入加）。
- 存储方法：`Storage.getAccounts()` / `saveAccounts()` / `adjustAccountBalance(id, delta)` / `deleteAccount(id)`（删除账户会清理历史记录上的 accountId 引用）。
- 记账页（`add_record_page.dart`）：新增「账户」选择入口，弹出底部 sheet 选账户或不计入。
- 预算页（`budget_page.dart`）：月预算卡片下方新增「账户余额」卡片，含「管理」入口可增删改账户与初始余额、显示总资产。
- 首页流水（`home_page.dart`）和历史账单（`history_page.dart`）的记录项会按 `record.accountId` 显示账户名标签（淡底小标签）；「微信」标签使用绿色（`0xFF07C160`），「支付宝」及其他使用主色。
- 注意：`IconData(a.icon, fontFamily:'MaterialIcons')` 在 spread 后接 `const` 控件会报 invalid_constant，渲染账户图标用辅助方法 `_accountIcon`/`accIcon` 返回非 const `Icon`。
