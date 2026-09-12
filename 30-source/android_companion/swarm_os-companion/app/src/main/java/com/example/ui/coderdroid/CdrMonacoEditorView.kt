package com.example.ui.coderdroid

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
import com.example.ui.theme.CarbonBackground
import com.example.ui.theme.TextMuted
import java.io.File

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun CdrMonacoEditorView(
    tab: CdrEditorTab?,
    onContentChanged: (tabId: String) -> Unit,
    onSaveRequested: (tabId: String, content: String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (tab == null) {
        CdrEmptyEditor(modifier)
        return
    }

    var webViewRef by remember { mutableStateOf<WebView?>(null) }
    var isReady by remember { mutableStateOf(false) }

    LaunchedEffect(tab.id, isReady) {
        if (isReady) webViewRef?.openFile(tab)
    }

    AndroidView(
        factory = { context ->
            WebView(context).apply {
                settings.apply {
                    javaScriptEnabled = true
                    allowFileAccessFromFileURLs = true
                    allowUniversalAccessFromFileURLs = true
                    domStorageEnabled = true
                }
                webViewClient = object : WebViewClient() {}
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

private fun WebView.openFile(tab: CdrEditorTab) {
    val file = File(tab.filePath)
    if (!file.exists()) return
    val content = file.readText()
        .replace("\\", "\\\\")
        .replace("`", "\\`")
        .replace("$", "\\$")
    val js = """
        window.coderdroid.openFile({
            tabId: `${tab.id}`,
            path: `${tab.filePath}`,
            language: `${tab.languageId}`,
            content: `$content`
        });
    """.trimIndent()
    post { evaluateJavascript(js, null) }
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
