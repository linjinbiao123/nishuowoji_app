package com.example.nishuowoji_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super 之前：super 会去 FlutterEngineCache 取引擎
        AppEngine.ensureEngine(this, MODE_MAIN)
        // 引擎是跨 Activity 复用且不会随 Activity 销毁的，
        // 若上一次是以快捷记账弹窗结束的，Dart 侧仍停在弹窗页面。
        // 这里在 super（attach FlutterView）之前先切回主界面，
        // 避免启动时闪一下记账弹窗。
        AppEngine.setMode(MODE_MAIN)
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        // 从快捷记账弹窗返回时，让 Dart 侧回到主界面并刷新数据
        AppEngine.setMode(MODE_MAIN)
    }

    override fun getCachedEngineId(): String = AppEngine.ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    private companion object {
        const val MODE_MAIN = "main"
    }
}
