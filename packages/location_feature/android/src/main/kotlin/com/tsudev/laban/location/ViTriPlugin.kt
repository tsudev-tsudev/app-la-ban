package com.tsudev.laban.location

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Vị trí qua LocationManager của hệ điều hành (KHÔNG Google Play Services -> không thêm SDK bên thứ ba, không
 * ảnh hưởng Data Safety). Android 12+ dùng FUSED_PROVIDER của chính LocationManager; máy cũ nghe GPS + mạng.
 *
 * Quyền chỉ xin khi người dùng bấm (just-in-time), chỉ "khi đang dùng". Huỷ nghe EventChannel -> thôi cập nhật.
 * Sự kiện: DoubleArray 10 số khớp `giaiMaDocViTri` phía Dart:
 * [vĩ, kinh, cao elipxoit, ±ngang, ±dọc, tốc độ, hướng, ms epoch, cao mực biển, nguồn]; NaN = không có.
 * Vị trí KHÔNG ghi log, không gửi ra khỏi máy.
 */
class ViTriPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var ngucanh: Context
    private lateinit var lenh: MethodChannel
    private lateinit var suKien: EventChannel
    private lateinit var quanLy: LocationManager
    private var hoatDong: ActivityPluginBinding? = null
    private var choQuyen: MethodChannel.Result? = null
    private var dich: EventChannel.EventSink? = null
    private val nghe = mutableListOf<LocationListener>()
    private var tot: Location? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ngucanh = binding.applicationContext
        quanLy = ngucanh.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        lenh = MethodChannel(binding.binaryMessenger, "la_ban/vi_tri")
        lenh.setMethodCallHandler(this)
        suKien = EventChannel(binding.binaryMessenger, "la_ban/vi_tri/su_kien")
        suKien.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        dung()
        lenh.setMethodCallHandler(null)
        suKien.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        hoatDong = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        hoatDong?.removeRequestPermissionsResultListener(this)
        hoatDong = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "quyen" -> result.success(quyen())
            "xinQuyen" -> xinQuyen(result)
            "dichVuBat" -> result.success(dichVuBat())
            "moCaiDatApp" -> {
                moCaiDat(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ngucanh.packageName, null)))
                result.success(null)
            }
            "moCaiDatViTri" -> {
                moCaiDat(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun moCaiDat(y: Intent) {
        val a = hoatDong?.activity
        if (a != null) a.startActivity(y) else ngucanh.startActivity(y.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun co(q: String) = ngucanh.checkSelfPermission(q) == PackageManager.PERMISSION_GRANTED

    private val tuyChon get() = ngucanh.getSharedPreferences("la_ban_vi_tri", Context.MODE_PRIVATE)

    /** Android không phân biệt "chưa hỏi" với "từ chối hẳn" -> tự nhớ đã hỏi chưa. */
    private fun quyen(): String {
        if (co(Manifest.permission.ACCESS_FINE_LOCATION)) return "chinhXac"
        if (co(Manifest.permission.ACCESS_COARSE_LOCATION)) return "xapXi"
        if (!tuyChon.getBoolean("daHoi", false)) return "chuaHoi"
        val a: Activity = hoatDong?.activity ?: return "tuChoi"
        return if (a.shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_COARSE_LOCATION)) "tuChoi" else "tuChoiHan"
    }

    private fun xinQuyen(result: MethodChannel.Result) {
        val a = hoatDong?.activity
        if (a == null || choQuyen != null) {
            result.success(quyen())
            return
        }
        choQuyen = result
        tuyChon.edit().putBoolean("daHoi", true).apply()
        a.requestPermissions(
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION),
            MA_YEU_CAU,
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != MA_YEU_CAU) return false
        choQuyen?.success(quyen())
        choQuyen = null
        return true
    }

    private fun dichVuBat(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) quanLy.isLocationEnabled
        else quanLy.isProviderEnabled(LocationManager.GPS_PROVIDER) || quanLy.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        dich = events
        val chuKyMs = ((arguments as? Map<*, *>)?.get("chuKyMs") as? Number)?.toLong() ?: 1000L
        if (!co(Manifest.permission.ACCESS_COARSE_LOCATION) && !co(Manifest.permission.ACCESS_FINE_LOCATION)) {
            events.error("quyen", null, null)
            return
        }
        val nguon = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && quanLy.allProviders.contains(LocationManager.FUSED_PROVIDER)) {
            listOf(LocationManager.FUSED_PROVIDER)
        } else {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).filter {
                quanLy.allProviders.contains(it) && (it != LocationManager.GPS_PROVIDER || co(Manifest.permission.ACCESS_FINE_LOCATION))
            }
        }
        try {
            // Vị trí gần nhất hiện ngay (bắc thực bật không cần chờ GPS bắt sóng), rồi cập nhật.
            nguon.mapNotNull { quanLy.getLastKnownLocation(it) }.maxByOrNull { it.time }?.let { nhan(it) }
            for (n in nguon) {
                val l = object : LocationListener {
                    override fun onLocationChanged(location: Location) = nhan(location)
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                    @Deprecated("API < 29")
                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                }
                quanLy.requestLocationUpdates(n, chuKyMs, 0f, l, Looper.getMainLooper())
                nghe.add(l)
            }
        } catch (e: SecurityException) {
            dung()
            events.error("quyen", null, null)
        }
    }

    override fun onCancel(arguments: Any?) = dung()

    private fun dung() {
        for (l in nghe) quanLy.removeUpdates(l)
        nghe.clear()
        dich = null
        tot = null
    }

    /** Hai nguồn (GPS + mạng) chạy song song: bỏ bản mạng kém hơn hẳn bản GPS còn mới. */
    private fun nhan(v: Location) {
        val cu = tot
        if (cu != null && v.time - cu.time < 10_000 && v.accuracy > cu.accuracy * 2 && v.provider != cu.provider) return
        tot = v
        val nan = Double.NaN
        val doc = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && v.hasVerticalAccuracy()) v.verticalAccuracyMeters.toDouble() else nan
        val mucBien = if (Build.VERSION.SDK_INT >= 34 && v.hasMslAltitude()) v.mslAltitudeMeters else nan
        val nguon = when (v.provider) {
            LocationManager.GPS_PROVIDER -> 0.0
            LocationManager.NETWORK_PROVIDER -> 1.0
            "fused" -> 2.0
            else -> 3.0
        }
        dich?.success(
            doubleArrayOf(
                v.latitude,
                v.longitude,
                if (v.hasAltitude()) v.altitude else nan,
                if (v.hasAccuracy()) v.accuracy.toDouble() else nan,
                doc,
                if (v.hasSpeed()) v.speed.toDouble() else nan,
                if (v.hasBearing()) v.bearing.toDouble() else nan,
                v.time.toDouble(),
                mucBien,
                nguon,
            ),
        )
    }

    private companion object {
        const val MA_YEU_CAU = 0x1ab4
    }
}
