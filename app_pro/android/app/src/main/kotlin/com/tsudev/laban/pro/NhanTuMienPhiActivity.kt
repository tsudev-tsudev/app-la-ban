package com.tsudev.laban.pro

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicReference

/**
 * M2b (QUYET_DINH Q66): bản miễn phí mở activity này (manifest: quyền `signature`) kèm URI gói trong Content Provider
 * của nó. Kiểm URI đúng provider của bản miễn phí cùng chứng chỉ, đọc gói (trần 64 MB) rồi đưa app Pro lên; Dart lấy
 * gói qua kênh `la_ban/chuyen_pro` và hiện màn xác nhận - chưa ghi gì trước khi người dùng đồng ý.
 */
class NhanTuMienPhiActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent?.data
        val goiMienPhi = KenhChuyenPro.goiMienPhi(this)
        val authority = "$goiMienPhi.chuyenpro"
        val hopLe = uri != null && uri.scheme == "content" && uri.authority == authority &&
            packageManager.resolveContentProvider(authority, 0)?.packageName == goiMienPhi &&
            KenhChuyenPro.mienPhiHopLe(this)
        if (!hopLe) {
            moApp()
            return
        }
        Thread {
            val byte = try {
                contentResolver.openInputStream(uri!!)?.use { vao ->
                    val ra = ByteArrayOutputStream()
                    val dem = ByteArray(64 * 1024)
                    var tong = 0
                    while (true) {
                        val n = vao.read(dem)
                        if (n < 0) break
                        tong += n
                        if (tong > TRAN_BYTE) error("qua-tran")
                        ra.write(dem, 0, n)
                    }
                    ra.toByteArray()
                }
            } catch (e: Exception) {
                null
            }
            if (byte != null && byte.isNotEmpty()) goi.set(byte)
            runOnUiThread { moApp() }
        }.start()
    }

    private fun moApp() {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            startActivity(it)
        }
        finish()
    }

    companion object {
        private const val TRAN_BYTE = 64 * 1024 * 1024
        private val goi = AtomicReference<ByteArray?>(null)

        fun layVaXoa(): ByteArray? = goi.getAndSet(null)
    }
}
