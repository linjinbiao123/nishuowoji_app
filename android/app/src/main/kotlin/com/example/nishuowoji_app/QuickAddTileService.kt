package com.example.nishuowoji_app

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import android.util.Log

/**
 * 通知栏快捷设置磁贴：点一下直接弹出记账窗口，不进入 App 主界面。
 *
 * 注意 API 24 才引入 TileService，而本应用 minSdk=23。
 * 这里不加 @RequiresApi 也能编译，但显式标注可以确保低版本设备
 * （系统本身不提供磁贴功能）不会误加载本类。
 */
@RequiresApi(24)
class QuickAddTileService : TileService() {

    override fun onTileAdded() {
        super.onTileAdded()
        refreshTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    /** 同步磁贴外观。方法名不能叫 updateTile()，否则会与 Tile.updateTile() 混淆 */
    private fun refreshTile() {
        qsTile?.apply {
            state = android.service.quicksettings.Tile.STATE_INACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        // 锁屏状态下不允许直接记账：先让用户验证身份，
        // 否则任何人拿到手机都能往账本里写数据
        if (isLocked) {
            unlockAndRun { launchQuickAdd() }
        } else {
            launchQuickAdd()
        }
    }

    private fun launchQuickAdd() {
        val intent = Intent(this, QuickAddActivity::class.java).apply {
            action = AppEngine.ACTION_QUICK_ADD
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ 禁止 TileService 直接 startActivity，只能通过 PendingIntent 启动。
            // 这里用 PendingIntent.send()（API 1 起可用，各版本行为一致），
            // 不依赖 launchActivityFromPendingIntent()，后者在本项目的 SDK 中不可用。
            // 面板收起由系统在启动新 task 的 Activity 时自动完成。
            try {
                PendingIntent.getActivity(
                    this,
                    REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                ).send()
            } catch (e: PendingIntent.CanceledException) {
                // PendingIntent 已被系统取消，此时无能为力，仅记录便于排查
                Log.w(TAG, "快捷记账 PendingIntent 被取消", e)
            }
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private companion object {
        const val REQUEST_CODE = 1001
        const val TAG = "QuickAddTile"
    }
}
