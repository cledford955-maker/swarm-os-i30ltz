package com.example.ui.coderdroid

import java.io.File
import java.util.UUID

// ── File tree node ─────────────────────────────────────────────────────────────

data class CdrFileNode(
    val file: File,
    val depth: Int = 0
) {
    val name: String get() = file.name
    val path: String get() = file.absolutePath
    val isDirectory: Boolean get() = file.isDirectory
    val extension: String get() = file.extension.lowercase()
    val languageId: String get() = when (extension) {
        "kt", "kts"        -> "kotlin"
        "java"             -> "java"
        "dart"             -> "dart"
        "py"               -> "python"
        "ts", "tsx"        -> "typescript"
        "js", "jsx"        -> "javascript"
        "json"             -> "json"
        "xml"              -> "xml"
        "gradle"           -> "groovy"
        "md"               -> "markdown"
        "html", "htm"      -> "html"
        "css"              -> "css"
        "rs"               -> "rust"
        "go"               -> "go"
        "c", "h"           -> "c"
        "cpp", "hpp"       -> "cpp"
        "sh"               -> "shell"
        "yaml", "yml"      -> "yaml"
        "toml"             -> "toml"
        "sql"              -> "sql"
        else               -> "plaintext"
    }
}

// ── Open editor tab ────────────────────────────────────────────────────────────

data class CdrEditorTab(
    val id: String = UUID.randomUUID().toString(),
    val fileNode: CdrFileNode,
    val isDirty: Boolean = false,
    val cursorLine: Int = 0,
    val cursorColumn: Int = 0
) {
    val title: String get() = if (isDirty) "${fileNode.name} •" else fileNode.name
    val languageId: String get() = fileNode.languageId
    val filePath: String get() = fileNode.path
}
