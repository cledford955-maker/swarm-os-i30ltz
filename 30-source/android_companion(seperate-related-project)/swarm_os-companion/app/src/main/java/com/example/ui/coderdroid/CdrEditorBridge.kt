package com.example.ui.coderdroid

import android.webkit.JavascriptInterface

/**
 * JavaScript-to-Kotlin bridge injected into the Monaco WebView.
 * Monaco calls these via window.Android.*
 */
class CdrEditorBridge(
    private val onContentChanged: (tabId: String) -> Unit,
    private val onCursorMoved: (line: Int, column: Int) -> Unit,
    private val onSaveRequested: (tabId: String, content: String) -> Unit,
    private val onReady: () -> Unit
) {
    @JavascriptInterface fun onContentChanged(tabId: String) = onContentChanged.invoke(tabId)
    @JavascriptInterface fun onCursorMoved(line: Int, column: Int) = onCursorMoved.invoke(line, column)
    @JavascriptInterface fun onSaveRequested(tabId: String, content: String) = onSaveRequested.invoke(tabId, content)
    @JavascriptInterface fun onReady() = onReady.invoke()
}
