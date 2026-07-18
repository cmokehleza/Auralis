package com.example.flutter_application_1

import android.content.ContentProvider
import android.content.ContentUris
import android.content.ContentValues
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.util.Size
import java.io.File
import java.io.FileOutputStream

/**
 * Supplies notification artwork through one always-valid content URI per song.
 *
 * Real embedded/MediaStore/folder artwork is returned when Android exposes it;
 * otherwise the provider renders the designed Auralis fallback into a PNG.
 * `audio_service` can therefore never receive a missing bitmap, and its bitmap
 * cache cannot retain another track's artwork because every URI contains the
 * stable Auralis track id.
 */
class NotificationArtworkProvider : ContentProvider() {
    companion object {
        private const val SIZE = 512
        private val fileLock = Any()
    }

    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String = "image/png"

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        require(!mode.contains('w')) { "Notification artwork is read-only." }
        val appContext = requireNotNull(context)
        val cacheDirectory = File(appContext.cacheDir, "notification_artwork")
        val cacheKey = Integer.toHexString(uri.toString().hashCode())
        val pngFile = File(cacheDirectory, "$cacheKey.png")

        synchronized(fileLock) {
            if (!pngFile.exists() || pngFile.length() == 0L) {
                cacheDirectory.mkdirs()
                val mediaId = uri.getQueryParameter("mediaId")?.toLongOrNull()
                val artwork = mediaId?.let(::loadTrackArtwork) ?: loadAuralisFallback()
                FileOutputStream(pngFile).use { output ->
                    if (!artwork.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                        throw IllegalStateException("Could not encode notification artwork.")
                    }
                    output.flush()
                }
                artwork.recycle()
            }
        }

        return ParcelFileDescriptor.open(pngFile, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    private fun loadTrackArtwork(mediaId: Long): Bitmap? {
        val appContext = context ?: return null
        val audioUri = ContentUris.withAppendedId(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            mediaId,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                appContext.contentResolver.loadThumbnail(
                    audioUri,
                    Size(SIZE, SIZE),
                    null,
                )?.let { return it }
            } catch (_: Exception) {
                // Some MediaStore providers do not expose audio thumbnails.
            }
        }

        try {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(appContext, audioUri)
                retriever.embeddedPicture?.let { bytes ->
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                }?.let { return it }
            } finally {
                retriever.release()
            }
        } catch (_: Exception) {
            // Continue to the album/folder artwork lookup.
        }

        return loadSiblingFolderArtwork(audioUri) ?: loadAlbumArtwork(audioUri)
    }

    @Suppress("DEPRECATION")
    private fun loadSiblingFolderArtwork(audioUri: Uri): Bitmap? {
        val resolver = context?.contentResolver ?: return null
        val audioPath = try {
            resolver.query(
                audioUri,
                arrayOf(MediaStore.Audio.Media.DATA),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            null
        } ?: return null

        val acceptedNames = setOf(
            "cover.jpg",
            "cover.jpeg",
            "cover.png",
            "folder.jpg",
            "folder.jpeg",
            "folder.png",
            "album.jpg",
            "album.jpeg",
            "album.png",
            "front.jpg",
            "front.jpeg",
            "front.png",
        )
        val candidates = try {
            File(audioPath).parentFile?.listFiles()?.asSequence()
                ?.filter { file -> file.isFile && file.name.lowercase() in acceptedNames }
                ?.sortedBy { file -> acceptedNames.indexOf(file.name.lowercase()) }
                ?.toList()
                .orEmpty()
        } catch (_: Exception) {
            emptyList()
        }
        for (candidate in candidates) {
            try {
                BitmapFactory.decodeFile(candidate.absolutePath)?.let { return it }
            } catch (_: Exception) {
                // Try the next conventional folder-art name.
            }
        }
        return null
    }

    private fun loadAlbumArtwork(audioUri: Uri): Bitmap? {
        val resolver = context?.contentResolver ?: return null
        val albumId = try {
            resolver.query(
                audioUri,
                arrayOf(MediaStore.Audio.Media.ALBUM_ID),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getLong(0) else null
            }
        } catch (_: Exception) {
            null
        } ?: return null

        val albumArtUri = ContentUris.withAppendedId(
            Uri.parse("content://media/external/audio/albumart"),
            albumId,
        )
        return try {
            resolver.openInputStream(albumArtUri)?.use(BitmapFactory::decodeStream)
        } catch (_: Exception) {
            null
        }
    }

    private fun loadAuralisFallback(): Bitmap {
        try {
            context?.assets
                ?.open("flutter_assets/assets/branding/auralis_icon_master.png")
                ?.use(BitmapFactory::decodeStream)
                ?.let { return it }
        } catch (_: Exception) {
            // The vector-style renderer below is a defensive cold-start fallback.
        }
        return drawAuralisFallback()
    }

    private fun drawAuralisFallback(): Bitmap {
        val bitmap = Bitmap.createBitmap(SIZE, SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        paint.shader = LinearGradient(
            0f,
            0f,
            SIZE.toFloat(),
            SIZE.toFloat(),
            intArrayOf(Color.rgb(8, 16, 34), Color.rgb(21, 67, 91), Color.rgb(10, 28, 51)),
            null,
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, SIZE.toFloat(), SIZE.toFloat(), paint)

        paint.shader = null
        paint.color = Color.argb(46, 104, 215, 255)
        canvas.drawCircle(96f, 88f, 176f, paint)
        paint.color = Color.argb(42, 93, 240, 184)
        canvas.drawCircle(430f, 430f, 214f, paint)

        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 24f
        paint.strokeCap = Paint.Cap.ROUND
        paint.strokeJoin = Paint.Join.ROUND
        paint.color = Color.rgb(131, 233, 255)
        val wave = Path().apply {
            moveTo(116f, 278f)
            cubicTo(164f, 278f, 172f, 176f, 224f, 176f)
            cubicTo(276f, 176f, 286f, 338f, 338f, 338f)
            cubicTo(382f, 338f, 394f, 252f, 430f, 252f)
        }
        canvas.drawPath(wave, paint)

        paint.style = Paint.Style.FILL
        paint.color = Color.WHITE
        canvas.drawCircle(116f, 278f, 22f, paint)
        canvas.drawCircle(430f, 252f, 22f, paint)
        return bitmap
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
