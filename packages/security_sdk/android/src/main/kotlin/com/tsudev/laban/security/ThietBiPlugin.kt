package com.tsudev.laban.security

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.view.WindowManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import com.google.android.play.core.integrity.model.StandardIntegrityErrorCode
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.Executors

/**
 * Định danh thiết bị (SEC-ID ID-02, ID-03):
 * - Khoá ECDSA P-256 trong Android Keystore, không xuất được (StrongBox nếu máy có, không thì TEE). Server chỉ nhận
 *   khoá công khai (SPKI DER); mọi chữ ký làm trong Keystore.
 * - Play Integrity Standard API: chuẩn bị provider một lần (theo số dự án Cloud), mỗi yêu cầu gắn requestHash do app
 *   tính từ thách thức của server. Kết quả CHỈ server giải mã + đánh giá.
 * - Kiểm tra môi trường (S4, [MoiTruong]) + FLAG_SECURE cho màn nhạy cảm.
 */
class ThietBiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var kenh: MethodChannel
    private lateinit var ngucanh: Context
    private val luong = Executors.newSingleThreadExecutor()
    private val chinh = Handler(Looper.getMainLooper())
    private var provider: StandardIntegrityTokenProvider? = null
    private var soDuAnProvider: Long = 0
    private var activity: Activity? = null
    private var cheBat = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ngucanh = binding.applicationContext
        kenh = MethodChannel(binding.binaryMessenger, "la_ban/thiet_bi")
        kenh.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        kenh.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        apCheManHinh()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun apCheManHinh() {
        val w = activity?.window ?: return
        if (cheBat) w.addFlags(WindowManager.LayoutParams.FLAG_SECURE) else w.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Keystore chậm (StrongBox hàng trăm ms) -> ngoài luồng UI.
            "khoaCongKhai" -> ngoaiLuong(result, "khoa.loi") { khoaCongKhai() }
            "ky" -> {
                val du = call.argument<ByteArray>("duLieu")
                if (du == null) result.error("ky.thieu", null, null) else ngoaiLuong(result, "ky.loi") { ky(du) }
            }
            // Không định danh phần cứng (CLAUDE.md): chỉ model + phiên bản Android + tên gói cho SOC / Play Integrity.
            "thongTin" -> result.success(
                mapOf("model" to Build.MODEL.take(64), "heDieuHanh" to Build.VERSION.RELEASE.take(32), "goi" to ngucanh.packageName),
            )
            "xoaKhoa" -> ngoaiLuong(result, "khoa.loi") {
                KeyStore.getInstance(KEYSTORE).apply { load(null) }.deleteEntry(BI_DANH)
                null
            }
            "integrity" -> {
                val soDuAn = call.argument<Number>("soDuAn")?.toLong()
                val bam = call.argument<String>("requestHash")
                if (soDuAn == null || bam == null) result.error("integrity.thieu", null, null) else integrity(soDuAn, bam, result, thuLai = true)
            }
            // Trang tải bản mới (S3 force / soft update), chính sách quyền riêng tư, thư yêu cầu về dữ liệu (A8a).
            // Chỉ mở trang / hộp thư của chính mình + trang Gói thuê bao của Google Play (M1a: huỷ / đổi gói) -
            // kênh này không phải trình mở URL chung.
            "moTrang" -> {
                val url = call.argument<String>("url")
                if (url == null || !(url.startsWith(TRANG_CHO_PHEP) || url.startsWith(THU_CHO_PHEP) || url.startsWith(PLAY_GOI_CHO_PHEP))) {
                    result.error("moTrang.url", null, null)
                } else {
                    try {
                        ngucanh.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
            }
            // Đọc /proc, thử cổng frida (<= 120 ms) -> ngoài luồng UI.
            "moiTruong" -> ngoaiLuong(result, "moiTruong.loi") { MoiTruong.kiemTra(ngucanh) }
            // S11 (Q57): Developer options / USB debugging / Wireless debugging - đọc Settings.Global (không cần quyền,
            // < 1 ms) nên gọi được mỗi lần resume / mỗi 2 giây khi đang hiện màn chặn.
            "cheDoPhatTrien" -> result.success(cheDoPhatTrien())
            "moCaiDatPhatTrien" -> result.success(moCaiDatPhatTrien())
            "cheManHinh" -> {
                cheBat = call.argument<Boolean>("bat") == true
                apCheManHinh()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun caiDatBat(ten: String): Boolean = try {
        Settings.Global.getInt(ngucanh.contentResolver, ten, 0) != 0
    } catch (_: Exception) {
        false
    }

    private fun cheDoPhatTrien(): Map<String, Boolean> = mapOf(
        "devMode" to caiDatBat(Settings.Global.DEVELOPMENT_SETTINGS_ENABLED),
        "adb" to caiDatBat(Settings.Global.ADB_ENABLED),
        // Settings.Global.ADB_WIFI_ENABLED là @hide - dùng tên khoá (Android 11+).
        "adbWifi" to caiDatBat("adb_wifi_enabled"),
    )

    /** Mở thẳng màn Tùy chọn nhà phát triển; máy chặn intent này thì mở Cài đặt chung. */
    private fun moCaiDatPhatTrien(): Boolean {
        val ds = listOf(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS, Settings.ACTION_SETTINGS)
        for (hd in ds) {
            try {
                val y = Intent(hd).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                (activity ?: ngucanh).startActivity(y)
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        return false
    }

    private fun ngoaiLuong(result: MethodChannel.Result, maLoi: String, viec: () -> Any?) {
        luong.execute {
            try {
                val kq = viec()
                chinh.post { result.success(kq) }
            } catch (e: Exception) {
                chinh.post { result.error(maLoi, e.javaClass.simpleName, null) }
            }
        }
    }

    @Synchronized
    private fun khoaCongKhai(): Map<String, Any> {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (!ks.containsAlias(BI_DANH)) taoKhoa()
        val chungChi = ks.getCertificate(BI_DANH) ?: throw IllegalStateException("khoa")
        val rieng = ks.getKey(BI_DANH, null) as PrivateKey
        val info = KeyFactory.getInstance(rieng.algorithm, KEYSTORE).getKeySpec(rieng, KeyInfo::class.java)
        val mucBaoMat = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            when (info.securityLevel) {
                KeyProperties.SECURITY_LEVEL_STRONGBOX -> "strongbox"
                KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "tee"
                KeyProperties.SECURITY_LEVEL_SOFTWARE -> "phan-mem"
                else -> "khac"
            }
        } else {
            @Suppress("DEPRECATION")
            if (info.isInsideSecureHardware) "tee" else "phan-mem"
        }
        return mapOf("spki" to chungChi.publicKey.encoded, "mucBaoMat" to mucBaoMat)
    }

    private fun taoKhoa() {
        fun tao(strongBox: Boolean) {
            val spec = KeyGenParameterSpec.Builder(BI_DANH, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
            if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) spec.setIsStrongBoxBacked(true)
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEYSTORE).apply { initialize(spec.build()) }.generateKeyPair()
        }
        val coStrongBox = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            ngucanh.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
        if (!coStrongBox) return tao(strongBox = false)
        try {
            tao(strongBox = true)
        } catch (e: Exception) {
            tao(strongBox = false)
        }
    }

    private fun ky(duLieu: ByteArray): ByteArray {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val rieng = ks.getKey(BI_DANH, null) as? PrivateKey ?: throw IllegalStateException("khoa")
        return Signature.getInstance("SHA256withECDSA").run {
            initSign(rieng)
            update(duLieu)
            sign()
        }
    }

    private fun integrity(soDuAn: Long, bam: String, result: MethodChannel.Result, thuLai: Boolean) {
        val coSan = provider
        if (coSan == null || soDuAnProvider != soDuAn) {
            IntegrityManagerFactory.createStandard(ngucanh)
                .prepareIntegrityToken(PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(soDuAn).build())
                .addOnSuccessListener { p ->
                    provider = p
                    soDuAnProvider = soDuAn
                    yeuCau(p, soDuAn, bam, result, thuLai)
                }
                .addOnFailureListener { e -> result.error("integrity.loi", maLoi(e), null) }
            return
        }
        yeuCau(coSan, soDuAn, bam, result, thuLai)
    }

    private fun yeuCau(p: StandardIntegrityTokenProvider, soDuAn: Long, bam: String, result: MethodChannel.Result, thuLai: Boolean) {
        p.request(StandardIntegrityTokenRequest.builder().setRequestHash(bam).build())
            .addOnSuccessListener { t -> result.success(t.token()) }
            .addOnFailureListener { e ->
                // Provider hết hạn (vài giờ / Play cập nhật) -> chuẩn bị lại một lần.
                if (thuLai && e is StandardIntegrityException &&
                    e.errorCode == StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID
                ) {
                    provider = null
                    integrity(soDuAn, bam, result, thuLai = false)
                } else {
                    result.error("integrity.loi", maLoi(e), null)
                }
            }
    }

    private fun maLoi(e: Exception): String =
        if (e is StandardIntegrityException) "ma-${e.errorCode}" else e.javaClass.simpleName

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val BI_DANH = "la_ban_thiet_bi_v1"
        const val TRANG_CHO_PHEP = "https://compass.tsudev.com/"
        const val THU_CHO_PHEP = "mailto:privacy@tsudev.com?"
        const val PLAY_GOI_CHO_PHEP = "https://play.google.com/store/account/subscriptions?"
    }
}
