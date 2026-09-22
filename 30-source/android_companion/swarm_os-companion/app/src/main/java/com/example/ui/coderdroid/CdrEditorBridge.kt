package com.example.ui.coderdroid

import android.webkit.JavascriptInterface

/**
 * JavaScript-to-Kotlin bridge injected into the Monaco WebView.
 * Monaco calls these via window.Android.*
 */
class CdrEditorBridge(
    private val onContentChanged: (tabId: String, content: String) -> Unit,
    private val onCursorMoved: (line: Int, column: Int) -> Unit,
    private val onSaveRequested: (tabId: String, content: String) -> Unit,
    private val onReady: () -> Unit
) {
    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    @JavascriptInterface fun onContentChanged(tabId: String, content: String) { main.post { onContentChanged.invoke(tabId, content) } }
    @JavascriptInterface fun onCursorMoved(line: Int, column: Int) { main.post { onCursorMoved.invoke(line, column) } }
    @JavascriptInterface fun onSaveRequested(tabId: String, content: String) { main.post { onSaveRequested.invoke(tabId, content) } }
    @JavascriptInterface fun onReady() { main.post { onReady.invoke() } }
}
