package com.tsudev.laban

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileNotFoundException

/**
 * M2b (QUYET_DINH Q66): phục vụ MỘT tệp gói chuyển dữ liệu cho La bàn Pro.
 *
 * Manifest đặt `readPermission` / `writePermission` = quyền `signature` -> chỉ app cùng chứng chỉ ký đọc được. Chỉ đọc,
 * chỉ đúng một tên tệp, gói cũ hơn [HAN_MS] bị xoá thay vì phục vụ.
 */
class ChuyenProProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val ctx = context ?: throw FileNotFoundException()
        if (mode != "r" || uri.pathSegments != listOf(TEN_TEP)) throw FileNotFoundException()
        val tep = tepGoi(ctx)
        if (!tep.isFile) throw FileNotFoundException()
        if (System.currentTimeMillis() - tep.lastModified() > HAN_MS) {
            tep.delete()
            throw FileNotFoundException()
        }
        return ParcelFileDescriptor.open(tep, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri): String? = if (uri.pathSegments == listOf(TEN_TEP)) "application/json" else null

    override fun query(uri: Uri, p: Array<out String>?, s: String?, a: Array<out String>?, o: String?): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun update(uri: Uri, v: ContentValues?, s: String?, a: Array<out String>?): Int = 0

    override fun delete(uri: Uri, s: String?, a: Array<out String>?): Int = 0

    companion object {
        const val TEN_TEP = "goi.json"
        const val HAN_MS = 10 * 60 * 1000L
        const val TRAN_BYTE = 64 * 1024 * 1024

        fun authority(ctx: Context): String = "${ctx.packageName}.chuyenpro"

        fun tepGoi(ctx: Context): File = File(File(ctx.cacheDir, "chuyen_pro"), TEN_TEP)
    }
}
