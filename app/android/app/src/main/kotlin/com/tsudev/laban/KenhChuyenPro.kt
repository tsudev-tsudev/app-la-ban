package com.tsudev.laban

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * M2b (QUYET_DINH Q56, Q66) - phía bản miễn phí của việc chuyển dữ liệu sang La bàn Pro.
 *
 * Gói JSON (do Dart dựng) ghi vào cache riêng của app rồi phục vụ qua [ChuyenProProvider] - provider chỉ mở cho app giữ
 * quyền `signature` (cùng chứng chỉ ký). Trước khi gửi, kiểm app Pro cùng chứng chỉ để không trao dữ liệu cho app giả
 * mạo trùng tên gói.
 */
class KenhChuyenPro(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val chinh = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ungDungKiaHopLe" -> result.success(proHopLe(activity))
            "moUngDungKia" -> result.success(moPro())
            "layYeuCau" -> result.success(
                if (MoChuyenProActivity.layVaXoa()) mapOf("loai" to "mo-chuyen") else null,
            )
            "guiSangPro" -> {
                val goi = call.argument<ByteArray>("goi")
                if (goi == null || goi.isEmpty() || goi.size > ChuyenProProvider.TRAN_BYTE || !proHopLe(activity)) {
                    result.success(false)
                    return
                }
                Thread {
                    val ok = try {
                        ghiGoi(goi)
                        true
                    } catch (e: Exception) {
                        false
                    }
                    chinh.post { result.success(ok && guiIntent()) }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun ghiGoi(goi: ByteArray) {
        val tep = ChuyenProProvider.tepGoi(activity)
        tep.parentFile?.mkdirs()
        val tam = File(tep.parentFile, "${tep.name}.tam")
        tam.writeBytes(goi)
        if (!tam.renameTo(tep)) {
            tam.delete()
            error("doi-ten")
        }
    }

    private fun guiIntent(): Boolean = try {
        val uri = Uri.Builder().scheme("content").authority(ChuyenProProvider.authority(activity))
            .appendPath(ChuyenProProvider.TEN_TEP).build()
        activity.startActivity(
            Intent(HANH_DONG_NHAN)
                .setClassName(goiPro(activity), "com.tsudev.laban.pro.NhanTuMienPhiActivity")
                .setDataAndType(uri, "application/json")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
        )
        true
    } catch (e: Exception) {
        false
    }

    private fun moPro(): Boolean = try {
        val i = activity.packageManager.getLaunchIntentForPackage(goiPro(activity))
        if (i == null || !proHopLe(activity)) false else {
            activity.startActivity(i)
            true
        }
    } catch (e: Exception) {
        false
    }

    companion object {
        const val HANH_DONG_NHAN = "com.tsudev.laban.action.NHAN_TU_MIEN_PHI"

        /** com.tsudev.laban[.dev|.stg] -> com.tsudev.laban.pro[.dev|.stg]. */
        fun goiPro(a: Activity): String = a.packageName.replaceFirst("com.tsudev.laban", "com.tsudev.laban.pro")

        fun proHopLe(a: Activity): Boolean {
            val pm = a.packageManager
            val goi = goiPro(a)
            return try {
                pm.getPackageInfo(goi, 0)
                pm.checkSignatures(a.packageName, goi) == PackageManager.SIGNATURE_MATCH
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }
}
