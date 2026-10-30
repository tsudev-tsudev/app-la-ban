package com.tsudev.laban.ar

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.net.Uri
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.Settings
import android.util.Size
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.TextureRegistry
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.max

/**
 * Camera AR (A7c): xem trước camera sau bằng Camera2 thuần, khung hình đi thẳng vào texture của Flutter
 * (SurfaceProducer) - không đọc pixel, không chụp, không lưu, không SDK ngoài (không ARCore).
 * Trả kèm trường nhìn tính từ tiêu cự + kích thước cảm biến để Dart chiếu hướng / điểm lên khung.
 */
class CameraArPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var kenh: MethodChannel
    private lateinit var textures: TextureRegistry
    private lateinit var ungDung: Context
    private var hoatDong: ActivityPluginBinding? = null
    private val chinh = Handler(Looper.getMainLooper())

    private var luong: HandlerThread? = null
    private var xuLy: Handler? = null
    private var camera: CameraDevice? = null
    private var phien: CameraCaptureSession? = null
    private var be: TextureRegistry.SurfaceProducer? = null
    private var choQuyen: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        kenh = MethodChannel(binding.binaryMessenger, "la_ban/camera_ar")
        kenh.setMethodCallHandler(this)
        textures = binding.textureRegistry
        ungDung = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        kenh.setMethodCallHandler(null)
        dong()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        hoatDong = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        hoatDong?.removeRequestPermissionsResultListener(this)
        hoatDong = null
        dong()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "mo" -> xinQuyenRoiMo(result)
            "coQuyen" -> result.success(
                ungDung.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED,
            )
            "dong" -> {
                dong()
                result.success(null)
            }
            "moCaiDat" -> {
                val act = hoatDong?.activity
                if (act == null) {
                    result.error("camera.khongActivity", null, null)
                    return
                }
                act.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", act.packageName, null)),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun xinQuyenRoiMo(result: MethodChannel.Result) {
        val act = hoatDong?.activity
        if (act == null) {
            result.error("camera.khongActivity", null, null)
            return
        }
        if (act.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            mo(result)
            return
        }
        if (choQuyen != null) {
            result.error("camera.dangHoi", null, null)
            return
        }
        choQuyen = result
        act.requestPermissions(arrayOf(Manifest.permission.CAMERA), YC_QUYEN)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != YC_QUYEN) return false
        val r = choQuyen ?: return true
        choQuyen = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            mo(r)
        } else if (grantResults.isEmpty()) {
            // Hộp thoại bị hệ thống huỷ (đổi cấu hình...) - không phải người dùng từ chối.
            r.error("camera.tuChoi", null, null)
        } else {
            // Không còn được hỏi lại (đã chọn "Không cho phép" hẳn) -> chỉ bật được trong Cài đặt.
            val act: Activity? = hoatDong?.activity
            val han = act != null && !act.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)
            r.error(if (han) "camera.tuChoiHan" else "camera.tuChoi", null, null)
        }
        return true
    }

    @SuppressLint("MissingPermission")
    private fun mo(result: MethodChannel.Result) {
        dong()
        val qlCamera = ungDung.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = try {
            qlCamera.cameraIdList.firstOrNull {
                qlCamera.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) ==
                    CameraMetadata.LENS_FACING_BACK
            }
        } catch (e: Exception) {
            null
        }
        if (id == null) {
            result.error("camera.khongCo", null, null)
            return
        }
        val dt = qlCamera.getCameraCharacteristics(id)
        val kichThuoc = chonKichThuoc(dt)
        val fov = truongNhin(dt, kichThuoc)
        val xoayCamBien = dt.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
        val doc = xoayCamBien % 180 != 0
        val producer = textures.createSurfaceProducer()
        producer.setSize(kichThuoc.width, kichThuoc.height)
        be = producer
        val t = HandlerThread("la-ban-camera-ar").also { it.start() }
        luong = t
        val h = Handler(t.looper)
        xuLy = h
        var daTra = false
        fun traLoi(ok: Boolean) {
            if (daTra) return
            daTra = true
            chinh.post {
                if (!ok) {
                    dong()
                    result.error("camera.khongCo", null, null)
                    return@post
                }
                // Khung hình theo màn hình dọc: cảm biến nằm ngang thì đổi rộng / cao và trường nhìn.
                val rong = if (doc) kichThuoc.height else kichThuoc.width
                val cao = if (doc) kichThuoc.width else kichThuoc.height
                result.success(
                    mapOf(
                        "texture" to producer.id(),
                        "rong" to rong,
                        "cao" to cao,
                        "fovNgang" to if (doc) fov.second else fov.first,
                        "fovDoc" to if (doc) fov.first else fov.second,
                        // Texture chưa xoay (ImageReader trên Impeller) -> Dart xoay theo cảm biến.
                        "xoay" to if (producer.handlesCropAndRotation()) 0 else xoayCamBien / 90,
                    ),
                )
            }
        }
        producer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                h.post { batPhien(producer.surface) }
            }

            override fun onSurfaceCleanup() {
                phien?.close()
                phien = null
            }
        })
        try {
            qlCamera.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(cd: CameraDevice) {
                    camera = cd
                    batPhien(producer.surface) { traLoi(it) }
                }

                override fun onDisconnected(cd: CameraDevice) {
                    cd.close()
                    if (camera === cd) camera = null
                    traLoi(false)
                }

                override fun onError(cd: CameraDevice, error: Int) {
                    cd.close()
                    if (camera === cd) camera = null
                    traLoi(false)
                }
            }, h)
        } catch (e: Exception) {
            traLoi(false)
        }
    }

    @Suppress("DEPRECATION")
    private fun batPhien(surface: Surface, xong: ((Boolean) -> Unit)? = null) {
        val cd = camera ?: return xong?.invoke(false) ?: Unit
        try {
            phien?.close()
            cd.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(s: CameraCaptureSession) {
                    phien = s
                    try {
                        val yc = cd.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                            addTarget(surface)
                            set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                            set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                        }
                        s.setRepeatingRequest(yc.build(), null, xuLy)
                        xong?.invoke(true)
                    } catch (e: Exception) {
                        xong?.invoke(false)
                    }
                }

                override fun onConfigureFailed(s: CameraCaptureSession) {
                    xong?.invoke(false)
                }
            }, xuLy)
        } catch (e: Exception) {
            xong?.invoke(false)
        }
    }

    private fun dong() {
        phien?.close()
        phien = null
        camera?.close()
        camera = null
        be?.release()
        be = null
        luong?.quitSafely()
        luong = null
        xuLy = null
    }

    companion object {
        private const val YC_QUYEN = 0x4152

        /** Xem trước tối đa ~1,5 MP: đủ nét cho màn điện thoại, nhẹ pin và băng thông GPU. */
        private const val DIEN_TICH_TOI_DA = 1440 * 1080

        /** Cùng tỉ lệ vùng cảm biến (thường 4:3) để giữ trọn trường nhìn, lớn nhất trong trần. */
        fun chonKichThuoc(dt: CameraCharacteristics): Size {
            val map = dt.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val ds = map?.getOutputSizes(SurfaceTexture::class.java).orEmpty()
            val vung = dt.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            val tiLe = if (vung != null) vung.width().toDouble() / vung.height() else 4.0 / 3
            return ds.filter { it.width * it.height <= DIEN_TICH_TOI_DA }
                .minWithOrNull(
                    compareBy<Size> { abs(it.width.toDouble() / it.height - tiLe) > 0.02 }
                        .thenByDescending { it.width * it.height },
                ) ?: ds.minByOrNull { it.width * it.height } ?: Size(1280, 720)
        }

        /** Trường nhìn (độ) ngang / dọc theo cảm biến nằm ngang của luồng [kt] (vùng bị cắt khi khác tỉ lệ). */
        fun truongNhin(dt: CameraCharacteristics, kt: Size): Pair<Double, Double> {
            val tieuCu = dt.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.firstOrNull()
            val vatLy = dt.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            val mang = dt.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
            val vung = dt.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            if (tieuCu == null || tieuCu <= 0f || vatLy == null) return 63.0 to 49.0
            var w = vatLy.width.toDouble()
            var h = vatLy.height.toDouble()
            if (mang != null && vung != null && mang.width > 0 && mang.height > 0) {
                w *= vung.width().toDouble() / mang.width
                h *= vung.height().toDouble() / mang.height
            }
            val tiLeLuong = kt.width.toDouble() / max(1, kt.height)
            if (tiLeLuong > w / h) h = w / tiLeLuong else w = h * tiLeLuong
            fun goc(canh: Double) = Math.toDegrees(2 * atan(canh / (2 * tieuCu)))
            return goc(w) to goc(h)
        }
    }
}
