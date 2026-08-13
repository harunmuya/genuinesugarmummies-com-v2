package com.genuinesugarmummies.global;

import android.Manifest;
import android.app.DownloadManager;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.webkit.DownloadListener;
import android.webkit.PermissionRequest;
import android.webkit.WebSettings;
import android.webkit.GeolocationPermissions;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.getcapacitor.BridgeActivity;
import com.getcapacitor.BridgeWebChromeClient;

import java.util.ArrayList;
import java.util.List;

/**
 * The native shell. It loads the deployed web app rather than bundled assets,
 * so almost everything is web, and the few things that are not are here.
 *
 * Three problems this fixes.
 *
 * Camera and microphone never worked in the WebView. A page calling
 * getUserMedia does not talk to Android directly: the WebView asks the app
 * through WebChromeClient.onPermissionRequest, and the default implementation
 * denies. Holding the OS permission made no difference, because nothing was
 * ever there to say yes. Video and voice calls could not have worked.
 *
 * The app also asked for camera and microphone the instant it opened, before
 * the user had done anything that needed either. That is the prompt people
 * refuse, and refusing twice sets "don't ask again", which breaks calling
 * permanently with no obvious way back. Permissions are now requested at the
 * moment the page asks for them, when the reason is on screen.
 *
 * And downloads did nothing. A WebView ignores a download link unless given a
 * DownloadListener, so the in-app update prompt appeared to be broken.
 */
public class MainActivity extends BridgeActivity {

    private static final int GS_MEDIA_PERMISSION_REQUEST = 7001;

    /**
     * The WebView's request, held while Android's own dialog is up.
     *
     * onPermissionRequest has to be answered with grant() or deny(), but the
     * OS prompt is asynchronous, so the request is parked here and answered in
     * onRequestPermissionsResult.
     */
    private PermissionRequest pendingRequest;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // No permission prompts here. See the class comment.
        bridgeMediaAndDownloads();
    }

    private void bridgeMediaAndDownloads() {
        if (bridge == null || bridge.getWebView() == null) return;

        WebSettings settings = bridge.getWebView().getSettings();
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setDomStorageEnabled(true);

        bridge.getWebView().setWebChromeClient(new BridgeWebChromeClient(bridge) {
            @Override
            public void onPermissionRequest(final PermissionRequest request) {
                runOnUiThread(() -> {
                    List<String> needed = new ArrayList<>();
                    for (String resource : request.getResources()) {
                        if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(resource)
                                && !granted(Manifest.permission.CAMERA)) {
                            needed.add(Manifest.permission.CAMERA);
                        }
                        if (PermissionRequest.RESOURCE_AUDIO_CAPTURE.equals(resource)
                                && !granted(Manifest.permission.RECORD_AUDIO)) {
                            needed.add(Manifest.permission.RECORD_AUDIO);
                        }
                    }

                    if (needed.isEmpty()) {
                        // Already held, so answer the page immediately.
                        request.grant(request.getResources());
                        return;
                    }

                    pendingRequest = request;
                    ActivityCompat.requestPermissions(
                            MainActivity.this,
                            needed.toArray(new String[0]),
                            GS_MEDIA_PERMISSION_REQUEST);
                });
            }

            @Override
            public void onPermissionRequestCanceled(PermissionRequest request) {
                if (pendingRequest == request) pendingRequest = null;
            }

            @Override
            public void onGeolocationPermissionsShowPrompt(
                    String origin, GeolocationPermissions.Callback callback) {
                // Distance between members is a core feature, and the app only
                // ever loads its own origin, so this follows the OS grant
                // rather than asking a second time in a different dialog.
                boolean allowed = granted(Manifest.permission.ACCESS_FINE_LOCATION)
                        || granted(Manifest.permission.ACCESS_COARSE_LOCATION);
                callback.invoke(origin, allowed, false);
            }
        });

        // Without this a WebView silently ignores a download link, which is
        // why the update prompt looked broken.
        bridge.getWebView().setDownloadListener(new DownloadListener() {
            @Override
            public void onDownloadStart(String url, String userAgent, String contentDisposition,
                                        String mimeType, long contentLength) {
                try {
                    DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                    request.setMimeType(mimeType);
                    request.addRequestHeader("User-Agent", userAgent);
                    request.setNotificationVisibility(
                            DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);

                    String name = URLUtilName(url, contentDisposition, mimeType);
                    request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name);

                    DownloadManager manager =
                            (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
                    if (manager != null) manager.enqueue(request);
                } catch (Exception ignored) {
                    // A failed download must not take the activity down with it.
                }
            }
        });
    }

    private static String URLUtilName(String url, String contentDisposition, String mimeType) {
        try {
            return android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType);
        } catch (Exception ignored) {
            return "download";
        }
    }

    private boolean granted(String permission) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true;
        return ContextCompat.checkSelfPermission(this, permission)
                == PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] results) {
        if (requestCode != GS_MEDIA_PERMISSION_REQUEST) {
            super.onRequestPermissionsResult(requestCode, permissions, results);
            return;
        }

        PermissionRequest request = pendingRequest;
        pendingRequest = null;
        if (request == null) return;

        boolean allGranted = results.length > 0;
        for (int result : results) {
            if (result != PackageManager.PERMISSION_GRANTED) allGranted = false;
        }

        // The page is waiting either way. Denying explicitly lets it show its
        // own explanation instead of hanging on a promise that never settles.
        if (allGranted) request.grant(request.getResources());
        else request.deny();
    }
}
