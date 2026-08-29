package com.example.nishuowoji_app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * 共享 Flutter 引擎管理 + 原生与 Dart 的通信中枢。
 *
 * 主界面（MainActivity）与快捷记账弹窗（QuickAddActivity）共用同一个引擎，
 * 这样从通知栏磁贴拉起弹窗时无需重新初始化 Dart，启动速度接近原生弹窗。
 *
 * 必须使用缓存引擎，否则每次拉起弹窗都要跑一遍 main()，
 * 而 main() 里的初始化（账本、通知、主题）会重复执行数秒。
 */
object AppEngine {
    const val ENGINE_ID = "nishuowoji_shared_engine"

    /** 与主界面的通信通道，Dart 侧需使用同名常量 */
    const val CHANNEL = "com.example.nishuowoji_app/quick_add"

    /** 快捷记账弹窗的启动 Action */
    const val ACTION_QUICK_ADD = "com.example.nishuowoji_app.QUICK_ADD"

    @Volatile
    private var mode: String = MODE_MAIN

    private var channel: MethodChannel? = null

    /** 由 QuickAddActivity 注入：Dart 侧保存完成后调用它来关闭弹窗 */
    var onFinishRequested: (() -> Unit)? = null

    private const val MODE_MAIN = "main"
    private const val MODE_QUICK_ADD = "quick_add"

    /**
     * 确保引擎已就绪。[initialMode] 只在首次创建引擎时生效，
     * 因为 Dart 的 main() 会在引擎创建时立即执行，
     * 它需要通过 getEntryMode 知道自己该渲染哪个页面。
     */
    @Synchronized
    fun ensureEngine(context: Context, initialMode: String): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }

        // 必须在 executeDartEntrypoint 之前设定，否则 Dart 首帧拿到的模式是错的
        mode = initialMode

        val engine = FlutterEngine(context.applicationContext)

        // 插件要在执行 Dart 之前注册，
        // 否则 main() 里的 await Storage.ensureDefaultLedger() 会因插件缺失而卡住
        GeneratedPluginRegistrant.registerWith(engine)

        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getEntryMode" -> result.success(mode)
                "finish" -> {
                    onFinishRequested?.invoke()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch

        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    /** 切换主界面/快捷记账，并通知 Dart 侧重建对应页面 */
    fun setMode(next: String) {
        if (mode == next) {
            // 模式没变也要通知：磁贴可能被再次点击，需要重置表单
            channel?.invokeMethod("entryModeChanged", next)
            return
        }
        mode = next
        channel?.invokeMethod("entryModeChanged", next)
    }

    fun currentMode(): String = mode
}
