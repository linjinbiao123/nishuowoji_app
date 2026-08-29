package com.example.nishuowoji_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

/**
 * 快捷记账弹窗。
 *
 * 它本身是一个独立的 Activity，但使用透明主题（QuickAddTheme），
 * 由 Flutter 绘制一个底部卡片，因此视觉上就是一个悬浮弹窗，
 * 而主界面不会被拉起，用户感知为"没打开 App"。
 *
 * 关键在于 getBackgroundMode() 必须返回 transparent —— 只设置主题不够，
 * 否则 Flutter 会用不透明的 SurfaceView 铺满屏幕，弹窗背后会变成纯黑。
 */
class QuickAddActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super 之前：super 会去 FlutterEngineCache 取引擎
        AppEngine.ensureEngine(this, MODE_QUICK_ADD)
        super.onCreate(savedInstanceState)
        AppEngine.onFinishRequested = { finishAndCollapse() }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        // 磁贴被再次点击（Activity 已存在）：把已有弹窗重置到初始状态
        if (intent != null) setIntent(intent)
        AppEngine.setMode(MODE_QUICK_ADD)
    }

    override fun onResume() {
        super.onResume()
        // 主界面此时被盖住，Dart 侧应渲染记账弹窗
        AppEngine.setMode(MODE_QUICK_ADD)
    }

    override fun onDestroy() {
        AppEngine.onFinishRequested = null
        super.onDestroy()
    }

    override fun getCachedEngineId(): String = AppEngine.ENGINE_ID

    /**
     * 必须重写 getBackgroundMode 而不是 getTransparencyMode。
     *
     * 框架内部 getTransparencyMode() 与 getRenderMode() 都以 getBackgroundMode() 为准：
     * 只改透明度而背景模式仍是 opaque 的话，渲染模式还是会选 surface，
     * 而 surface 不支持透明，弹窗背后会变成纯黑。
     */
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    /** 引擎由 AppEngine 缓存并跨 Activity 共享，绝不随本 Activity 销毁 */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    private fun finishAndCollapse() {
        finish()
        // 关掉弹窗时不播放 Activity 转场动画，
        // 让它看起来像"弹窗消失"而不是"页面切换"
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    private companion object {
        const val MODE_QUICK_ADD = "quick_add"
    }
}
