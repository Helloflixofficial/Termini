package com.helloflix.termini

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationChannel = "community_posts"
    private val notificationPermissionRequest = 4812

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "termini/local_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequest)
                        }
                        result.success(null)
                    }
                    "updatePreferences" -> {
                        val sound = call.argument<Boolean>("sound") ?: true
                        val vibration = call.argument<Boolean>("vibration") ?: true
                        createNotificationChannel(sound, vibration, recreate = true)
                        result.success(null)
                    }
                    "clear" -> {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            manager.activeNotifications
                                .filter { it.notification.channelId == notificationChannel }
                                .forEach { manager.cancel(it.tag, it.id) }
                        }
                        result.success(null)
                    }
                    "show" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "New post from Termini"
                        val body = call.argument<String>("body") ?: "A teacher shared a post in Community."
                        val sound = call.argument<Boolean>("sound") ?: true
                        val vibration = call.argument<Boolean>("vibration") ?: true
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        ) {
                            val launchIntent = Intent(this, MainActivity::class.java)
                            val pendingIntent = PendingIntent.getActivity(
                                this,
                                0,
                                launchIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                            )
                            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                android.app.Notification.Builder(this, notificationChannel)
                            } else {
                                android.app.Notification.Builder(this)
                            }
                            val notification = builder
                                .setSmallIcon(R.drawable.termini_notification_icon)
                                .setContentTitle(title)
                                .setContentText(body)
                                .setStyle(android.app.Notification.BigTextStyle().bigText(body))
                                .setContentIntent(pendingIntent)
                                .setAutoCancel(true)
                                .apply {
                                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                                        val defaults = (if (sound) android.app.Notification.DEFAULT_SOUND else 0) or
                                            (if (vibration) android.app.Notification.DEFAULT_VIBRATE else 0)
                                        setDefaults(defaults)
                                    }
                                }
                                .build()
                            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            manager.notify(id, notification)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun createNotificationChannel(
        sound: Boolean = true,
        vibration: Boolean = true,
        recreate: Boolean = false,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (recreate) manager.deleteNotificationChannel(notificationChannel)
            val channel = NotificationChannel(
                notificationChannel,
                "Community posts",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Alerts when teachers share new community posts"
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(
                    if (sound) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) else null,
                    audioAttributes,
                )
                enableVibration(vibration)
                if (vibration) vibrationPattern = longArrayOf(0, 250, 150, 250)
            }
            manager.createNotificationChannel(channel)
        }
    }
}
