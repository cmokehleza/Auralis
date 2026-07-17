package com.example.flutter_application_1

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.widget.RemoteViews
import java.io.File

class AuralisWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, views(context)) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val keyCode = when (intent.action) {
            ACTION_PREVIOUS -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            ACTION_TOGGLE -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            else -> return
        }
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
    }

    companion object {
        private const val ACTION_PREVIOUS = "com.auralis.widget.PREVIOUS"
        private const val ACTION_TOGGLE = "com.auralis.widget.TOGGLE"
        private const val ACTION_NEXT = "com.auralis.widget.NEXT"
        private const val PREFS = "auralis_widget"

        fun storeAndRefresh(
            context: Context,
            title: String,
            artist: String,
            positionMs: Int,
            durationMs: Int,
            playing: Boolean,
            artwork: ByteArray?,
            artworkProvided: Boolean,
        ) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("title", title)
                .putString("artist", artist)
                .putInt("position", positionMs)
                .putInt("duration", durationMs.coerceAtLeast(1))
                .putBoolean("playing", playing)
                .apply()
            if (artworkProvided) {
                val file = File(context.filesDir, "auralis_widget_art.jpg")
                if (artwork == null || artwork.isEmpty()) {
                    file.delete()
                } else {
                    file.writeBytes(artwork)
                }
            }
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, AuralisWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach {
                manager.updateAppWidget(it, views(context))
            }
        }

        private fun views(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return RemoteViews(context.packageName, R.layout.auralis_widget).apply {
                setTextViewText(R.id.widget_title, prefs.getString("title", "Nothing playing"))
                setTextViewText(R.id.widget_artist, prefs.getString("artist", "Auralis"))
                setProgressBar(
                    R.id.widget_progress,
                    prefs.getInt("duration", 1),
                    prefs.getInt("position", 0),
                    false,
                )
                val artFile = File(context.filesDir, "auralis_widget_art.jpg")
                val bitmap = if (artFile.exists()) BitmapFactory.decodeFile(artFile.path) else null
                if (bitmap == null) {
                    setImageViewResource(R.id.widget_art, R.mipmap.ic_launcher)
                } else {
                    setImageViewBitmap(R.id.widget_art, bitmap)
                }
                val playing = prefs.getBoolean("playing", false)
                setImageViewResource(
                    R.id.widget_toggle,
                    if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                )
                setOnClickPendingIntent(R.id.widget_previous, action(context, ACTION_PREVIOUS, 1))
                setOnClickPendingIntent(R.id.widget_toggle, action(context, ACTION_TOGGLE, 2))
                setOnClickPendingIntent(R.id.widget_next, action(context, ACTION_NEXT, 3))
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launch?.let {
                    setOnClickPendingIntent(
                        R.id.widget_art,
                        PendingIntent.getActivity(
                            context,
                            4,
                            it,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                        ),
                    )
                }
            }
        }

        private fun action(context: Context, action: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, AuralisWidgetProvider::class.java).setAction(action)
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
