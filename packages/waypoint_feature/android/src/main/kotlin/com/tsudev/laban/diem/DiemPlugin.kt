package com.tsudev.laban.diem

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Tab Điểm (A6): chọn ảnh, lưu / mở tệp GPX-KML, chia sẻ link. Chỉ dùng Intent hệ thống (Photo Picker,
 * Storage Access Framework, ACTION_SEND) -> KHÔNG cần quyền đọc bộ nhớ / ảnh, không SDK ngoài.
 * Ảnh được giải mã lại thành JPEG mới: bỏ toàn bộ EXIF (vị trí GPS, máy chụp) trước khi vào CSDL.
 */
class DiemPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var kenh: MethodChannel
    private var hoatDong: ActivityPluginBinding? = null
    private val luong = Executors.newSingleThreadExecutor()
    private val chinh = Handler(Looper.getMainLooper())

    /** Lời gọi đang chờ kết quả Activity (mỗi lúc chỉ một hộp thoại hệ thống). */
    private var cho: MethodChannel.Result? = null
    private var choYeuCau = 0
    private var duLieuLuu: ByteArray? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        kenh = MethodChannel(binding.binaryMessenger, "la_ban/diem")
        kenh.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        kenh.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        hoatDong = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        hoatDong?.removeActivityResultListener(this)
        hoatDong = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val act = hoatDong?.activity
        if (act == null) {
            result.error("diem.khongActivity", null, null)
            return
        }
        when (call.method) {
            "chonAnh" -> moHopThoai(result, YC_ANH, intentChonAnh())
            "luuTep" -> {
                duLieuLuu = call.argument<ByteArray>("duLieu")
                val i = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = call.argument<String>("mime")
                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("ten"))
                }
                moHopThoai(result, YC_LUU, i)
            }
            "moTep" -> {
                // GPX / KML không có MIME thống nhất giữa các app -> mở mọi tệp, Dart tự nhận dạng nội dung.
                val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                moHopThoai(result, YC_MO, i)
            }
            "chiaSeChu" -> {
                val gui = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, call.argument<String>("chu"))
                }
                act.startActivity(Intent.createChooser(gui, call.argument<String>("tieuDe")))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun intentChonAnh(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(MediaStore.ACTION_PICK_IMAGES).apply { type = "image/*" }
        } else {
            Intent(Intent.ACTION_GET_CONTENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
            }
        }

    private fun moHopThoai(result: MethodChannel.Result, yeuCau: Int, i: Intent) {
        if (cho != null) {
            result.error("diem.dangMo", null, null)
            return
        }
        cho = result
        choYeuCau = yeuCau
        try {
            hoatDong!!.activity.startActivityForResult(i, yeuCau)
        } catch (e: ActivityNotFoundException) {
            cho = null
            duLieuLuu = null
            result.error("diem.khongCoApp", e.javaClass.simpleName, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != choYeuCau || cho == null) return false
        val result = cho!!
        cho = null
        val uri = data?.data
        val luu = duLieuLuu
        duLieuLuu = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == YC_LUU) false else null)
            return true
        }
        val cr = hoatDong!!.activity.contentResolver
        luong.execute {
            try {
                val kq: Any? = when (requestCode) {
                    YC_ANH -> docAnh(cr, uri)
                    YC_LUU -> {
                        cr.openOutputStream(uri, "wt")!!.use { it.write(luu!!) }
                        true
                    }
                    else -> docTep(cr, uri)
                }
                chinh.post { result.success(kq) }
            } catch (e: Exception) {
                chinh.post { result.error("diem.io", e.javaClass.simpleName, null) }
            }
        }
        return true
    }

    private fun docTep(cr: ContentResolver, uri: Uri): ByteArray {
        cr.openInputStream(uri)!!.use { vao ->
            val ra = ByteArrayOutputStream()
            val dem = ByteArray(64 * 1024)
            while (true) {
                val n = vao.read(dem)
                if (n < 0) break
                ra.write(dem, 0, n)
                if (ra.size() > TEP_TOI_DA) throw IllegalStateException("tep.quaLon")
            }
            return ra.toByteArray()
        }
    }

    /** Giải mã ảnh thu nhỏ (cạnh dài <= CANH_TOI_DA), xoay theo EXIF, nén JPEG mới (không EXIF). */
    private fun docAnh(cr: ContentResolver, uri: Uri): Map<String, Any> {
        val bien = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        cr.openInputStream(uri)!!.use { BitmapFactory.decodeStream(it, null, bien) }
        if (bien.outWidth <= 0 || bien.outHeight <= 0) throw IllegalStateException("anh.hong")
        var mau = 1
        while (maxOf(bien.outWidth, bien.outHeight) / (mau * 2) >= CANH_TOI_DA) mau *= 2
        val tuyChon = BitmapFactory.Options().apply { inSampleSize = mau }
        var bmp = cr.openInputStream(uri)!!.use { BitmapFactory.decodeStream(it, null, tuyChon) }
            ?: throw IllegalStateException("anh.hong")
        val xoay = try {
            cr.openInputStream(uri)!!.use {
                when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
            }
        } catch (_: Exception) {
            0f
        }
        val lon = maxOf(bmp.width, bmp.height)
        val tiLe = if (lon > CANH_TOI_DA) CANH_TOI_DA.toFloat() / lon else 1f
        if (xoay != 0f || tiLe < 1f) {
            val m = Matrix().apply {
                postScale(tiLe, tiLe)
                postRotate(xoay)
            }
            val moi = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
            if (moi !== bmp) bmp.recycle()
            bmp = moi
        }
        val ra = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 82, ra)
        val kq = mapOf("duLieu" to ra.toByteArray(), "rong" to bmp.width, "cao" to bmp.height)
        bmp.recycle()
        return kq
    }

    private companion object {
        const val YC_ANH = 0x4C41
        const val YC_LUU = 0x4C42
        const val YC_MO = 0x4C43
        const val CANH_TOI_DA = 1600
        const val TEP_TOI_DA = 20 * 1024 * 1024
    }
}
