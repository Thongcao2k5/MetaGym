package com.metagym.meta_gym_app

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.metagym.meta_gym_app/media_permission"
    private val requestCodeMedia = 4102
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(currentStatus())
                    "getSelectedPhotos" -> result.success(loadGrantedPhotos(limit = 12))
                    "request" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "Permission request already in progress", null)
                            return@setMethodCallHandler
                        }
                        val permissions = when {
                            Build.VERSION.SDK_INT >= 34 -> arrayOf(
                                Manifest.permission.READ_MEDIA_IMAGES,
                                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
                            )
                            Build.VERSION.SDK_INT >= 33 -> arrayOf(
                                Manifest.permission.READ_MEDIA_IMAGES,
                            )
                            else -> arrayOf(
                                Manifest.permission.READ_EXTERNAL_STORAGE,
                            )
                        }
                        pendingResult = result
                        ActivityCompat.requestPermissions(this, permissions, requestCodeMedia)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun loadGrantedPhotos(limit: Int): List<ByteArray> {
        val photos = mutableListOf<ByteArray>()
        val projection = arrayOf(MediaStore.Images.Media._ID)
        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"
        try {
            contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                sortOrder,
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                while (cursor.moveToNext() && photos.size < limit) {
                    val id = cursor.getLong(idCol)
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        id,
                    )
                    contentResolver.openInputStream(uri)?.use { stream ->
                        val original = BitmapFactory.decodeStream(stream)
                        if (original != null) {
                            val maxDim = 800
                            val ratio = minOf(
                                maxDim.toFloat() / original.width.coerceAtLeast(1),
                                maxDim.toFloat() / original.height.coerceAtLeast(1),
                                1.0f,
                            )
                            val scaled = if (ratio < 1.0f) {
                                Bitmap.createScaledBitmap(
                                    original,
                                    (original.width * ratio).toInt().coerceAtLeast(1),
                                    (original.height * ratio).toInt().coerceAtLeast(1),
                                    true,
                                )
                            } else {
                                original
                            }
                            val out = ByteArrayOutputStream()
                            scaled.compress(Bitmap.CompressFormat.JPEG, 85, out)
                            photos.add(out.toByteArray())
                        }
                    }
                }
            }
        } catch (_: Exception) {
        }
        return photos
    }

    private fun currentStatus(): String {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return "FULL"
        }
        if (Build.VERSION.SDK_INT >= 34 &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return "SELECTED"
        }
        if (Build.VERSION.SDK_INT < 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return "FULL"
        }
        return "DENIED"
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == requestCodeMedia) {
            val callback = pendingResult
            pendingResult = null
            callback?.success(currentStatus())
        }
    }
}
