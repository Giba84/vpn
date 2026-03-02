package com.example.my_vpn_app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.VpnService;
import android.os.Build;
import android.os.IBinder;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.TimeUnit;

public class XrayVpnService extends VpnService {

    private static final String TAG = "XrayVpnService";
    private static final int NOTIFICATION_ID = 1;
    private static final String CHANNEL_ID = "xray_vpn";

    public static final String ACTION_START = "com.example.my_vpn_app.START";
    public static final String ACTION_STOP = "com.example.my_vpn_app.STOP";
    public static final String EXTRA_CONFIG = "config_json";

    private ParcelFileDescriptor vpnInterface;
    private Process xrayProcess;
    private boolean isRunning = false;
    private final Object lock = new Object();

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Xray VPN Service",
                    NotificationManager.IMPORTANCE_LOW
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            manager.createNotificationChannel(channel);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_NOT_STICKY;

        String action = intent.getAction();
        if (ACTION_START.equals(action)) {
            String configJson = intent.getStringExtra(EXTRA_CONFIG);
            if (configJson == null || configJson.isEmpty()) {
                Log.e(TAG, "No config provided");
                return START_NOT_STICKY;
            }
            startVpn(configJson);
        } else if (ACTION_STOP.equals(action)) {
            stopVpn();
        }
        return START_NOT_STICKY;
    }

    private void startVpn(String configJson) {
        synchronized (lock) {
            if (isRunning) {
                Log.w(TAG, "Already running");
                return;
            }
            isRunning = true;
        }

        // 1. Создаём VPN-интерфейс
        Builder builder = new Builder();
        builder.setSession("Xray VPN");
        builder.addAddress("10.89.64.1", 32);
        builder.addRoute("0.0.0.0", 0);
        builder.addDnsServer("8.8.8.8");
        builder.addDnsServer("8.8.4.4");

        // Пытаемся исключить наше приложение из VPN
        try {
            builder.addDisallowedApplication(getPackageName());
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "Failed to exclude own package from VPN", e);
        }

        vpnInterface = builder.establish();
        if (vpnInterface == null) {
            Log.e(TAG, "Failed to establish VPN interface");
            synchronized (lock) { isRunning = false; }
            return;
        }

        // 2. Сохраняем конфиг во временный файл
        File configFile = new File(getFilesDir(), "config.json");
        try (FileOutputStream fos = new FileOutputStream(configFile)) {
            fos.write(configJson.getBytes());
            fos.flush();
            fos.getFD().sync();
            Log.i(TAG, "Config written to " + configFile.getAbsolutePath());
        } catch (IOException e) {
            Log.e(TAG, "Failed to write config", e);
            stopVpn();
            return;
        }

        // 3. Извлекаем бинарник Xray из assets
        File xrayBinary = new File(getFilesDir(), "xray");
        if (!xrayBinary.exists()) {
            try (InputStream is = getAssets().open("xray");
                 OutputStream os = new FileOutputStream(xrayBinary)) {
                byte[] buffer = new byte[8192];
                int len;
                while ((len = is.read(buffer)) != -1) {
                    os.write(buffer, 0, len);
                }
                os.flush();
                Log.i(TAG, "Xray binary extracted");
            } catch (IOException e) {
                Log.e(TAG, "Failed to extract xray binary", e);
                stopVpn();
                return;
            }
        }

        // Устанавливаем права на выполнение
        if (!xrayBinary.setExecutable(true)) {
            Log.e(TAG, "Failed to set executable permission on xray binary");
            stopVpn();
            return;
        }

        // 4. Запускаем Xray-процесс
        try {
            ProcessBuilder pb = new ProcessBuilder(xrayBinary.getAbsolutePath(), "-c", configFile.getAbsolutePath());
            pb.directory(getFilesDir());
            pb.redirectErrorStream(true);
            xrayProcess = pb.start();

            // Читаем логи Xray для отладки
            new Thread(() -> {
                try (InputStream is = xrayProcess.getInputStream()) {
                    byte[] buffer = new byte[1024];
                    int len;
                    while ((len = is.read(buffer)) != -1) {
                        Log.d("Xray", new String(buffer, 0, len));
                    }
                } catch (IOException e) {
                    Log.e(TAG, "Error reading Xray output", e);
                }
            }).start();

            // 5. Переходим в foreground
            startForeground(NOTIFICATION_ID, createNotification());
            Log.i(TAG, "Xray process started");
        } catch (IOException e) {
            Log.e(TAG, "Failed to start Xray", e);
            stopVpn();
        }
    }

    private void stopVpn() {
        synchronized (lock) {
            if (!isRunning) return;
            isRunning = false;
        }

        if (xrayProcess != null) {
            xrayProcess.destroy();
            try {
                if (!xrayProcess.waitFor(3, TimeUnit.SECONDS)) {
                    xrayProcess.destroyForcibly();
                }
            } catch (InterruptedException ignored) {}
            xrayProcess = null;
        }

        if (vpnInterface != null) {
            try {
                vpnInterface.close();
            } catch (IOException e) {
                Log.e(TAG, "Error closing VPN interface", e);
            }
            vpnInterface = null;
        }

        stopForeground(true);
        stopSelf();
    }

    private Notification createNotification() {
        Intent intent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Xray VPN")
                .setContentText("VPN is running")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onRevoke() {
        stopVpn();
    }

    @Override
    public void onDestroy() {
        stopVpn();
        super.onDestroy();
    }
}