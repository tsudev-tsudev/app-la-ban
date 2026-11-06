package com.tsudev.laban

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import java.util.concurrent.atomic.AtomicBoolean

/**
 * M2b (QUYET_DINH Q66): La bàn Pro bấm "Lấy từ La bàn trên máy này" -> mở activity này (manifest: quyền `signature`),
 * đánh dấu yêu cầu rồi đưa app về màn chính; Dart đọc cờ qua kênh `la_ban/chuyen_pro` và mở màn chuyển.
 */
class MoChuyenProActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        yeuCau.set(true)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            startActivity(it)
        }
        finish()
    }

    companion object {
        private val yeuCau = AtomicBoolean(false)

        fun layVaXoa(): Boolean = yeuCau.getAndSet(false)
    }
}
