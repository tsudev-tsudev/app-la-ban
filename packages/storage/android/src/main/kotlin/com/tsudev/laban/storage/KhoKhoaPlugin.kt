package com.tsudev.laban.storage

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Khoá CSDL (SEC-APP-STORAGE): 32 byte ngẫu nhiên, lưu ở `noBackupFilesDir` dưới dạng đã bọc
 * AES-256-GCM bằng khoá Android Keystore không xuất được (StrongBox nếu máy có). Keystore không
 * theo bản sao lưu / chuyển máy, nên tệp CSDL có bị sao chép đi cũng không giải mã được.
 */
class KhoKhoaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var kenh: MethodChannel
    private lateinit var ngucanh: Context
    private val luong = Executors.newSingleThreadExecutor()
    private val chinh = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ngucanh = binding.applicationContext
        kenh = MethodChannel(binding.binaryMessenger, "la_ban/luu_tru")
        kenh.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        kenh.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Keystore chậm (hàng chục ms, StrongBox lâu hơn) -> chạy ngoài luồng UI.
            "layKhoaCsdl" -> luong.execute {
                try {
                    val khoa = layKhoaCsdl()
                    chinh.post { result.success(khoa) }
                } catch (e: Exception) {
                    chinh.post { result.error("khoa.loi", e.javaClass.simpleName, null) }
                }
            }
            "thuMucDuLieu" -> result.success(ngucanh.noBackupFilesDir.absolutePath)
            // Màn Quyền riêng tư (A8a): xoá MỌI dữ liệu của app như "Xoá dữ liệu" trong Cài đặt hệ thống -
            // tệp, CSDL, bản đồ offline, bộ nhớ đệm - rồi hệ thống đóng app. Khoá Keystore của app xoá
            // trước cho chắc (không phụ thuộc bản Android). Thành công thì không có kết quả trả về.
            "xoaToanBo" -> luong.execute {
                try {
                    val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
                    ks.aliases().toList().forEach { ks.deleteEntry(it) }
                } catch (_: Exception) {
                }
                val am = ngucanh.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                if (!am.clearApplicationUserData()) chinh.post { result.error("xoa.loi", null, null) }
            }
            else -> result.notImplemented()
        }
    }

    @Synchronized
    private fun layKhoaCsdl(): ByteArray {
        val tep = File(ngucanh.noBackupFilesDir, TEP_KHOA)
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (tep.exists() && ks.containsAlias(BI_DANH)) {
            try {
                return moBoc(tep.readBytes(), ks.getKey(BI_DANH, null) as SecretKey)
            } catch (e: Exception) {
                // Khoá Keystore bị vô hiệu (đổi khoá màn hình trên vài máy, khôi phục máy):
                // sinh khoá mới; CSDL cũ không mở được -> Dart dời sang .hong.
            }
        }
        val boc = taoKhoaBoc()
        val khoa = ByteArray(DO_DAI_KHOA).also { SecureRandom().nextBytes(it) }
        val c = Cipher.getInstance(THUAT_TOAN).apply { init(Cipher.ENCRYPT_MODE, boc) }
        val iv = c.iv
        val ma = c.doFinal(khoa)
        val tam = File(tep.parentFile, "$TEP_KHOA.tam")
        tam.writeBytes(byteArrayOf(PHIEN_BAN, iv.size.toByte()) + iv + ma)
        if (!tam.renameTo(tep)) throw IllegalStateException("ghi")
        return khoa
    }

    private fun moBoc(du: ByteArray, boc: SecretKey): ByteArray {
        require(du.size > 2 && du[0] == PHIEN_BAN)
        val doDaiIv = du[1].toInt()
        val iv = du.copyOfRange(2, 2 + doDaiIv)
        val c = Cipher.getInstance(THUAT_TOAN)
        c.init(Cipher.DECRYPT_MODE, boc, GCMParameterSpec(128, iv))
        val khoa = c.doFinal(du.copyOfRange(2 + doDaiIv, du.size))
        require(khoa.size == DO_DAI_KHOA)
        return khoa
    }

    private fun taoKhoaBoc(): SecretKey {
        fun tao(strongBox: Boolean): SecretKey {
            val spec = KeyGenParameterSpec.Builder(
                BI_DANH,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                spec.setIsStrongBoxBacked(true)
            }
            return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
                .apply { init(spec.build()) }
                .generateKey()
        }
        val coStrongBox = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            ngucanh.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
        if (!coStrongBox) return tao(strongBox = false)
        // Bắt Exception chung (StrongBoxUnavailableException chỉ có từ API 28).
        return try {
            tao(strongBox = true)
        } catch (e: Exception) {
            tao(strongBox = false)
        }
    }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val BI_DANH = "la_ban_csdl_v1"
        const val TEP_KHOA = "khoa_csdl.bin"
        const val THUAT_TOAN = "AES/GCM/NoPadding"
        const val DO_DAI_KHOA = 32
        const val PHIEN_BAN: Byte = 1
    }
}
