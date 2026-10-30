package com.tsudev.laban.security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import java.security.MessageDigest

/**
 * Kiểm tra môi trường (SEC-APP APP-02, APP-03). Phần dễ bị hook ở tầng Java (đường dẫn su, thư viện Frida, thuộc tính
 * máy ảo...) nằm trong thư viện C++ `la_ban_kt` (native/android/cpp); ở đây chỉ phần cần API Android. Kết quả là TÍN
 * HIỆU gửi server, không phải quyết định.
 */
internal object MoiTruong {
    /** Bitmask của C++ - tên `k` giữ nguyên qua R8 nhờ consumer-rules.pro (RegisterNatives tìm theo tên). */
    @JvmStatic
    private external fun k(): Int

    private val coNative: Boolean = try {
        System.loadLibrary("la_ban_kt")
        true
    } catch (_: Throwable) {
        false
    }

    fun kiemTra(ngucanh: Context): Map<String, Any?> {
        var bit = if (coNative) {
            try {
                k()
            } catch (_: Throwable) {
                -1
            }
        } else {
            -1
        }
        // Chrome OS (ARC) chạy app Android hợp lệ trên máy ảo - không coi là giả lập (Spec §7.3b).
        if (bit > 0 && laChromeOs(ngucanh)) bit = bit and BIT_QEMU.inv()
        val ai = ngucanh.applicationInfo
        return mapOf(
            "native" to bit,
            "jdwp" to (Debug.isDebuggerConnected() || Debug.waitingForDebugger()),
            "appDebuggable" to (ai.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0),
            "testKeys" to (Build.TAGS?.contains("test-keys") == true),
            "chungChi" to chungChi(ngucanh),
            "nguonCai" to nguonCai(ngucanh),
        )
    }

    private fun laChromeOs(ngucanh: Context) =
        ngucanh.packageManager.hasSystemFeature("org.chromium.arc") ||
            ngucanh.packageManager.hasSystemFeature("org.chromium.arc.device_management")

    /** SHA-256 (hex thường) chứng chỉ ký gói đang chạy - so ở Dart với chứng chỉ khoá upload (APP-03). */
    @Suppress("DEPRECATION")
    private fun chungChi(ngucanh: Context): List<String> = try {
        val pm = ngucanh.packageManager
        val goi = ngucanh.packageName
        val ds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val si = pm.getPackageInfo(goi, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo
            when {
                si == null -> emptyArray()
                si.hasMultipleSigners() -> si.apkContentsSigners
                else -> si.signingCertificateHistory
            }
        } else {
            pm.getPackageInfo(goi, PackageManager.GET_SIGNATURES).signatures
        }
        ds.orEmpty().map { s ->
            MessageDigest.getInstance("SHA-256").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
        }
    } catch (_: Exception) {
        emptyList()
    }

    @Suppress("DEPRECATION")
    private fun nguonCai(ngucanh: Context): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ngucanh.packageManager.getInstallSourceInfo(ngucanh.packageName).installingPackageName
        } else {
            ngucanh.packageManager.getInstallerPackageName(ngucanh.packageName)
        }
    } catch (_: Exception) {
        null
    }

    private const val BIT_QEMU = 1 shl 8
}
