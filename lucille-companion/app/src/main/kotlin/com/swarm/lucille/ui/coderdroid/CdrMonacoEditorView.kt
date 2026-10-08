package com.swarm.lucille.ui.coderdroid

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.swarm.lucille.ui.theme.CarbonBackground
import com.swarm.lucille.ui.theme.TextMuted
import java.io.File
import org.json.JSONObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun CdrMonacoEditorView(
    tab: CdrEditorTab?,
    onContentChanged: (tabId: String, content: String) -> Unit,
    onSaveRequested: (tabId: String, content: String) -> Unit,
    drafts: Map<String, String> = emptyMap(),
    modifier: Modifier = Modifier
) {
    if (tab == null) {
        CdrEmptyEditor(modifier)
        return
    }

    var webViewRef by remember { mutableStateOf<WebView?>(null) }
    var isReady by remember { mutableStateOf(false) }

    LaunchedEffect(tab.id, isReady) {
        if (isReady) {
            val content = drafts[tab.id] ?: withContext(Dispatchers.IO) {
                runCatching { require(File(tab.filePath).length() <= 2 * 1024 * 1024) { "File exceeds 2 MiB editor limit" }; File(tab.filePath).readText() }.getOrElse { "Unable to read file: ${it.message}" }
            }
            val data = JSONObject().put("tabId", tab.id).put("path", tab.filePath).put("language", tab.languageId).put("content", content)
            webViewRef?.evaluateJavascript("window.coderdroid.openFile($data);", null)
        }
    }

    DisposableEffect(Unit) { onDispose { webViewRef?.destroy(); webViewRef = null } }

    AndroidView(
        factory = { context ->
            WebView(context).apply {
                settings.apply {
                    javaScriptEnabled = true
                    allowFileAccessFromFileURLs = true
                    allowUniversalAccessFromFileURLs = false
                    domStorageEnabled = true
                }
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: android.webkit.WebResourceRequest?) = true
                    override fun shouldInterceptRequest(view: WebView?, request: android.webkit.WebResourceRequest?): android.webkit.WebResourceResponse? {
                        val url = request?.url.toString()
                        return if (url.startsWith("file:///android_asset/monaco/")) null else android.webkit.WebResourceResponse("text/plain", "UTF-8", java.io.ByteArrayInputStream(byteArrayOf()))
                    }
                }
                addJavascriptInterface(
                    CdrEditorBridge(
                        onContentChanged = onContentChanged,
                        onCursorMoved    = { _, _ -> },
                        onSaveRequested  = onSaveRequested,
                        onReady          = { isReady = true }
                    ),
                    "Android"
                )
                loadUrl("file:///android_asset/monaco/editor.html")
                webViewRef = this
            }
        },
        modifier = modifier
    )
}

@Composable
private fun CdrEmptyEditor(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(CarbonBackground),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "Open a file from the explorer →",
            fontSize = 13.sp,
            color = TextMuted,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
        )
    }
}
