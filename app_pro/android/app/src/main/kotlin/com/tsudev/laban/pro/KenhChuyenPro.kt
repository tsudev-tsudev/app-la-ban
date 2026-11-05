package com.tsudev.laban.pro

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * M2b (QUYET_DINH Q56, Q66) - phía La bàn Pro của việc chuyển dữ liệu. Gói do [NhanTuMienPhiActivity] đọc từ Content
 * Provider của bản miễn phí, giữ trong bộ nhớ tới khi Dart lấy (một lần).
 */
class KenhChuyenPro(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ungDungKiaHopLe" -> result.success(mienPhiHopLe(activity))
            "moUngDungKia" -> result.success(moMienPhi())
            "layYeuCau" -> result.success(NhanTuMienPhiActivity.layVaXoa()?.let { mapOf("loai" to "goi", "duLieu" to it) })
            "guiSangPro" -> result.success(false)
            else -> result.notImplemented()
        }
    }

    private fun moMienPhi(): Boolean = try {
        if (!mienPhiHopLe(activity)) false else {
            activity.startActivity(
                Intent(HANH_DONG_MO_CHUYEN).setClassName(goiMienPhi(activity), "com.tsudev.laban.MoChuyenProActivity"),
            )
            true
        }
    } catch (e: Exception) {
        false
    }

    companion object {
        const val HANH_DONG_MO_CHUYEN = "com.tsudev.laban.action.MO_CHUYEN_PRO"

        /** com.tsudev.laban.pro[.dev|.stg] -> com.tsudev.laban[.dev|.stg]. */
        fun goiMienPhi(ctx: Context): String = ctx.packageName.replaceFirst("com.tsudev.laban.pro", "com.tsudev.laban")

        fun mienPhiHopLe(ctx: Context): Boolean {
            val pm = ctx.packageManager
            val goi = goiMienPhi(ctx)
            return try {
                pm.getPackageInfo(goi, 0)
                pm.checkSignatures(ctx.packageName, goi) == PackageManager.SIGNATURE_MATCH
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }
}
