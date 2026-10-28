package com.tsudev.laban.sensors

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.view.Display
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Cảm biến định hướng cho la bàn (Spec 4.1). Lắng nghe SensorManager trên một HandlerThread riêng
 * (không chặn luồng UI), gom mẫu thành lô DoubleArray phẳng mỗi ~16 ms rồi gửi qua EventChannel -
 * một thông điệp / khung hình thay vì vài trăm. Định dạng mỗi mẫu (7 số, khớp `giaiMaLo` phía Dart):
 * [loai, tNs, x, y, z, w (NaN nếu không có), doChinhXac].
 *
 * Không gửi tên / hãng cảm biến (tránh thành dấu vân tay thiết bị). Huỷ nghe -> huỷ đăng ký hết.
 */
class CamBienPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var lenh: MethodChannel
    private lateinit var suKien: EventChannel
    private lateinit var quanLy: SensorManager
    private lateinit var manHinh: DisplayManager
    private val chinh = Handler(Looper.getMainLooper())

    private var luong: HandlerThread? = null
    private var xuLy: Handler? = null
    private var dich: EventChannel.EventSink? = null
    private var chuKyUs = CHU_KY_MAC_DINH

    // Chỉ chạm trên luồng cảm biến.
    private var dem = DoubleArray(SO_TRUONG * 64)
    private var soMau = 0
    private var xoayCuoi = -1

    private val loaiTheoDoi = intArrayOf(
        Sensor.TYPE_ROTATION_VECTOR,
        Sensor.TYPE_GAME_ROTATION_VECTOR,
        Sensor.TYPE_MAGNETIC_FIELD,
        Sensor.TYPE_ACCELEROMETER,
        Sensor.TYPE_GYROSCOPE,
        Sensor.TYPE_PRESSURE,
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val ngucanh = binding.applicationContext
        quanLy = ngucanh.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        manHinh = ngucanh.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        lenh = MethodChannel(binding.binaryMessenger, "la_ban/cam_bien")
        lenh.setMethodCallHandler(this)
        suKien = EventChannel(binding.binaryMessenger, "la_ban/cam_bien/su_kien")
        suKien.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        dung()
        lenh.setMethodCallHandler(null)
        suKien.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "khaNang" -> result.success(
                mapOf(
                    "xoayVector" to co(Sensor.TYPE_ROTATION_VECTOR),
                    "xoayGame" to co(Sensor.TYPE_GAME_ROTATION_VECTOR),
                    "tu" to co(Sensor.TYPE_MAGNETIC_FIELD),
                    "giaToc" to co(Sensor.TYPE_ACCELEROMETER),
                    "conQuay" to co(Sensor.TYPE_GYROSCOPE),
                    "apSuat" to co(Sensor.TYPE_PRESSURE),
                ),
            )
            "datChuKy" -> {
                chuKyUs = docChuKy(call.argument<Int>("chuKyUs"))
                // Đang phát -> đăng ký lại với chu kỳ mới (SensorManager không đổi tại chỗ).
                xuLy?.post {
                    quanLy.unregisterListener(nghe)
                    dangKy()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        dung()
        dich = events
        chuKyUs = docChuKy((arguments as? Map<*, *>)?.get("chuKyUs") as? Int)
        val l = HandlerThread("la_ban_cam_bien").also { it.start() }
        luong = l
        val h = Handler(l.looper)
        xuLy = h
        h.post {
            soMau = 0
            xoayCuoi = -1
            dangKy()
            h.postDelayed(xa, KHOANG_LO_MS)
        }
    }

    override fun onCancel(arguments: Any?) = dung()

    private fun co(loai: Int) = quanLy.getDefaultSensor(loai) != null

    private fun docChuKy(v: Int?) = (v ?: CHU_KY_MAC_DINH).coerceIn(CHU_KY_MIN, CHU_KY_MAX)

    private fun dangKy() {
        val h = xuLy ?: return
        for (loai in loaiTheoDoi) {
            val cb = quanLy.getDefaultSensor(loai) ?: continue
            // Khí áp đổi chậm, 5 Hz là đủ.
            val ck = if (loai == Sensor.TYPE_PRESSURE) 200_000 else chuKyUs
            quanLy.registerListener(nghe, cb, ck, 0, h)
        }
    }

    private fun dung() {
        val h = xuLy
        xuLy = null
        dich = null
        quanLy.unregisterListener(nghe)
        h?.removeCallbacksAndMessages(null)
        luong?.quitSafely()
        luong = null
    }

    private val nghe = object : SensorEventListener {
        override fun onSensorChanged(e: SensorEvent) {
            val loai = when (e.sensor.type) {
                Sensor.TYPE_ROTATION_VECTOR -> 0
                Sensor.TYPE_GAME_ROTATION_VECTOR -> 1
                Sensor.TYPE_MAGNETIC_FIELD -> 2
                Sensor.TYPE_ACCELEROMETER -> 3
                Sensor.TYPE_GYROSCOPE -> 4
                Sensor.TYPE_PRESSURE -> 5
                else -> return
            }
            val v = e.values
            val w = if (loai <= 1 && v.size >= 4) v[3].toDouble() else Double.NaN
            them(
                loai.toDouble(),
                e.timestamp.toDouble(),
                v[0].toDouble(),
                if (v.size > 1) v[1].toDouble() else 0.0,
                if (v.size > 2) v[2].toDouble() else 0.0,
                w,
                e.accuracy.toDouble(),
            )
        }

        override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
    }

    private fun them(vararg so: Double) {
        if ((soMau + 1) * SO_TRUONG > dem.size) dem = dem.copyOf(dem.size * 2)
        System.arraycopy(so, 0, dem, soMau * SO_TRUONG, SO_TRUONG)
        soMau++
    }

    private val xa: Runnable = object : Runnable {
        override fun run() {
            val h = xuLy ?: return
            val xoay = manHinh.getDisplay(Display.DEFAULT_DISPLAY)?.rotation ?: 0
            if (xoay != xoayCuoi) {
                xoayCuoi = xoay
                them(6.0, SystemClock.elapsedRealtimeNanos().toDouble(), xoay.toDouble(), 0.0, 0.0, Double.NaN, 3.0)
            }
            if (soMau > 0) {
                val lo = dem.copyOf(soMau * SO_TRUONG)
                soMau = 0
                chinh.post { dich?.success(lo) }
            }
            h.postDelayed(this, KHOANG_LO_MS)
        }
    }

    private companion object {
        const val SO_TRUONG = 7
        const val KHOANG_LO_MS = 16L
        const val CHU_KY_MAC_DINH = 10_000
        const val CHU_KY_MIN = 5_000
        const val CHU_KY_MAX = 200_000
    }
}
