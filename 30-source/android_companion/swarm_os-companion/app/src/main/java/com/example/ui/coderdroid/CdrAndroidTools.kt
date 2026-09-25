package com.example.ui.coderdroid

import android.app.Application
import android.content.Intent
import androidx.core.content.FileProvider
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.data.config.SwarmConnection
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import org.eclipse.jgit.api.Git
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

data class AndroidToolsState(val busy: Boolean = false, val status: String = "Check your paired computer to begin.", val log: String = "", val id: String = "", val built: Boolean = false, val apk: File? = null, val buildHost: String = "")

class AndroidToolsViewModel(app: Application) : AndroidViewModel(app) {
    val state = MutableStateFlow(AndroidToolsState())
    private val connection = SwarmConnection(app)
    private val client = OkHttpClient.Builder().connectTimeout(10, TimeUnit.SECONDS).readTimeout(150, TimeUnit.SECONDS).writeTimeout(150, TimeUnit.SECONDS).build()
    private fun request(path: String) = Request.Builder().url(connection.httpBase() + "/api/android/" + path).header("X-Swarm-Auth", connection.authToken)
    private fun json(path: String, body: RequestBody? = null): JSONObject {
        val req = request(path).apply { if (body != null) post(body) }.build()
        return client.newCall(req).execute().use { response ->
            val text = response.body?.string().orEmpty()
            check(response.isSuccessful) { "HTTP ${response.code}: ${text.take(500)}" }
            JSONObject(text)
        }
    }
    private fun work(block: suspend () -> Unit) {
        if (state.value.busy) return
        state.update { it.copy(busy = true) }
        viewModelScope.launch(Dispatchers.IO) {
            try { block() } catch (e: Exception) {
                if(e is CancellationException) throw e
                state.update { it.copy(status = "Failed: ${e.message}") }
            } finally { state.update { it.copy(busy = false) } }
        }
    }
    fun checkHost() = work {
        val result = json("capabilities")
        state.update { it.copy(status = "${connection.host}: SDK ${result.optBoolean("sdkAvailable")}, Java ${result.optBoolean("javaAvailable")}, ADB ${result.optBoolean("adbAvailable")}") }
    }
    fun build(root: File) = work {
        state.update { AndroidToolsState(busy = true, status = "Preparing saved project…", buildHost = connection.httpBase()) }
        val archive = File.createTempFile("project-", ".zip", getApplication<Application>().cacheDir)
        try {
            zipProject(root, archive)
            val result = json("builds", archive.asRequestBody("application/zip".toMediaType()))
            val id = result.getString("id")
            state.update { it.copy(id = id, status = "Building on ${connection.host}…") }
            var completed = false
            while (!completed) {
                delay(2000)
                check(connection.httpBase() == state.value.buildHost) { "Build computer changed; return to the original node to retrieve this build." }
                val job = json("builds/$id")
                val status = job.getString("state")
                completed = status != "running"
                state.update { it.copy(log = job.optString("log").takeLast(30000), built = status == "success", status = when(status) { "success" -> "APK built. Download it to this phone or install via ADB."; "failed" -> "Build failed: ${job.optString("error")}"; else -> "Building on ${connection.host}…" }) }
            }
        } finally { archive.delete() }
    }
    fun download() = work {
        check(connection.httpBase() == state.value.buildHost) { "Select the computer that built this APK." }
        val id = state.value.id
        require(id.isNotBlank() && state.value.built)
        val dir = File(getApplication<Application>().filesDir, "apks").apply { mkdirs() }
        val temp = File(dir, "$id.part")
        val output = File(dir, "$id.apk")
        try {
            client.newCall(request("builds/$id/apk").build()).execute().use { response ->
                check(response.isSuccessful) { "APK download returned HTTP ${response.code}" }
                val body = checkNotNull(response.body)
                require(body.contentLength() <= 300L * 1024 * 1024) { "APK exceeds 300 MiB" }
                body.byteStream().use { input -> temp.outputStream().use { out ->
                    val buffer = ByteArray(65536); var total = 0L
                    while(true) { val n = input.read(buffer); if(n < 0) break; total += n; require(total <= 300L*1024*1024); out.write(buffer, 0, n) }
                    check(body.contentLength() < 0 || total == body.contentLength()) { "Incomplete APK" }
                } }
            }
            java.util.zip.ZipFile(temp).use { check(it.getEntry("AndroidManifest.xml") != null) { "Response is not an APK" } }
            check(temp.renameTo(output)) { "Unable to save APK" }
            state.update { it.copy(apk = output, status = "APK saved. Install on this phone opens Android's installer.") }
        } finally { temp.delete() }
    }
    fun devices() = work { state.update { it.copy(log = json("devices").getString("output"), status = "Devices attached or paired to ${connection.host}") } }
    fun adb(action: String, address: String, code: String, serial: String) = work {
        if (action == "install") check(connection.httpBase() == state.value.buildHost) { "Select the computer that built this APK." }
        val body = JSONObject().put("action", action).put("address", address.trim()).put("code", code.trim()).put("serial", serial.trim()).put("buildId", state.value.id)
        val result = json("adb", body.toString().toRequestBody("application/json".toMediaType()))
        state.update { it.copy(status = if(result.optBoolean("success")) "ADB $action completed" else "ADB $action failed", log = result.optString("output")) }
    }
    fun createProject(name: String, appId: String, onCreated: (File) -> Unit) = work {
        require(name.matches(Regex("[A-Za-z][A-Za-z0-9_-]{0,60}"))) { "Use a project name with letters, numbers, - or _." }
        require(appId.matches(Regex("[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*){2,}"))) { "Use an application ID such as com.yourname.myapp" }
        require(appId != "com.aistudio.sysopt.app") { "Choose your own application ID" }
        val root = File(getApplication<Application>().filesDir, "projects/$name")
        require(!root.exists()) { "A project with this name already exists" }
        root.mkdirs()
        fun write(path: String, text: String) { File(root,path).apply { parentFile?.mkdirs(); writeText(text) } }
        write("settings.gradle.kts", "pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ndependencyResolutionManagement { repositories { google(); mavenCentral() } }\nrootProject.name = \"$name\"\ninclude(\":app\")\n")
        write("build.gradle.kts", "plugins { id(\"com.android.application\") version \"9.2.1\" apply false }\n")
        write("app/build.gradle.kts", "plugins { id(\"com.android.application\") }\nandroid { namespace = \"$appId\"; compileSdk = 36\n defaultConfig { applicationId = \"$appId\"; minSdk = 24; targetSdk = 36; versionCode = 1; versionName = \"1.0\" } }\n")
        write("app/src/main/AndroidManifest.xml", "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"><application android:label=\"$name\" android:theme=\"@android:style/Theme.Material.Light.NoActionBar\"><activity android:name=\".MainActivity\" android:exported=\"true\"><intent-filter><action android:name=\"android.intent.action.MAIN\"/><category android:name=\"android.intent.category.LAUNCHER\"/></intent-filter></activity></application></manifest>")
        write("app/src/main/java/${appId.replace('.', '/')}/MainActivity.java", "package $appId;\nimport android.app.Activity;\nimport android.os.Bundle;\nimport android.widget.TextView;\npublic class MainActivity extends Activity { @Override public void onCreate(Bundle savedInstanceState) { super.onCreate(savedInstanceState); TextView text = new TextView(this); text.setText(\"Hello from $name\"); text.setTextSize(24); text.setPadding(32,64,32,32); setContentView(text); } }\n")
        write(".gitignore", ".gradle/\n**/build/\nlocal.properties\n.env\n*.jks\n*.keystore\n")
        for (path in listOf("gradlew", "gradle/wrapper/gradle-wrapper.jar", "gradle/wrapper/gradle-wrapper.properties")) {
            File(root,path).apply { parentFile?.mkdirs(); outputStream().use { out -> getApplication<Application>().assets.open("android-template/$path").use { it.copyTo(out) } } }
        }
        Git.init().setDirectory(root).call().close()
        state.update { it.copy(status = "Created $name. Edit MainActivity.java, save, then Build APK.") }
        withContext(Dispatchers.Main) { onCreated(root) }
    }
    override fun onCleared() { client.dispatcher.cancelAll(); super.onCleared() }
}

internal fun zipProject(root: File, output: File) {
    val canonical = root.canonicalFile
    require(File(root,"gradlew").isFile) { "Open an Android Gradle project with gradlew, or create a new app." }
    var total = 0L; var count = 0
    ZipOutputStream(output.outputStream()).use { zip ->
        root.walkTopDown().onEnter { it == root || it.name !in setOf(".git", ".gradle", "build", "node_modules", ".idea") && it.canonicalFile == it.absoluteFile }.forEach { file ->
            if(!file.isFile) return@forEach
            val path = file.relativeTo(root).invariantSeparatorsPath
            if(file.name == "local.properties" || file.name.startsWith(".env") || file.extension in setOf("jks", "keystore", "apk", "aab")) return@forEach
            require(file.canonicalPath.startsWith(canonical.path + File.separator) && file.canonicalFile == file.absoluteFile) { "Symbolic links are not included in builds: $path" }
            total += file.length(); count++
            require(total <= 100L*1024*1024 && count <= 10000) { "Project exceeds upload limit (100 MiB / 10,000 files)" }
            zip.putNextEntry(ZipEntry(path)); file.inputStream().use { it.copyTo(zip) }; zip.closeEntry()
        }
    }
    require(output.length() <= 100L*1024*1024) { "Compressed project exceeds 100 MiB" }
}

@Composable
fun CdrAndroidTools(root: File?, unsaved: Boolean, onDismiss: () -> Unit, onProjectCreated: (File) -> Unit, model: AndroidToolsViewModel = viewModel()) {
    val state by model.state.collectAsState()
    val context = LocalContext.current
    var name by remember { mutableStateOf("") }; var appId by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }; var code by remember { mutableStateOf("") }; var serial by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Android apps & ADB") }, text = {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Edit on this phone. Builds and ADB run on the computer configured in Remote PC. Build runs your project's Gradle code on that computer; use projects you trust. A phone-only compiler is not included.")
            Text(state.status)
            if(state.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            TextButton(onClick = model::checkHost, enabled = !state.busy) { Text("Check build computer") }
            Button(onClick = { root?.let(model::build) }, enabled = root != null && !unsaved && !state.busy) { Text("Build APK") }
            if(unsaved) Text("Save all edited files before building.")
            if(state.built) Button(onClick = model::download, enabled = !state.busy) { Text("Download APK") }
            state.apk?.let { apk -> Button(onClick = {
                runCatching {
                    val uri = FileProvider.getUriForFile(context, context.packageName + ".files", apk)
                    context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                }.onFailure { message = "Installer: ${it.message}" }
            }) { Text("Install on this phone") } }
            Text("New Android app")
            OutlinedTextField(name, {name=it}, label={Text("Project name")}, singleLine=true)
            OutlinedTextField(appId, {appId=it}, label={Text("Application ID: com.yourname.myapp")}, singleLine=true)
            TextButton(onClick={model.createProject(name,appId,onProjectCreated)}, enabled=!state.busy && !unsaved) { Text("Create project") }
            HorizontalDivider()
            Text("ADB on paired computer. USB requires device authorization. For Android 11+ wireless debugging, pair first, then connect using the separate connection port shown by Android.")
            TextButton(onClick=model::devices, enabled=!state.busy) { Text("List ADB devices") }
            OutlinedTextField(address,{address=it},label={Text("Device IP:port")},singleLine=true)
            OutlinedTextField(code,{code=it},label={Text("Six-digit pairing code")},singleLine=true, visualTransformation=androidx.compose.ui.text.input.PasswordVisualTransformation())
            Row { TextButton(onClick={model.adb("pair",address,code,""); code=""},enabled=!state.busy){Text("Pair")}; TextButton(onClick={model.adb("connect",address,"","")},enabled=!state.busy){Text("Connect")} }
            OutlinedTextField(serial,{serial=it},label={Text("Exact device serial from list")},singleLine=true)
            Button(onClick={model.adb("install","","",serial)},enabled=!state.busy && state.built && serial.isNotBlank()){Text("Install APK via ADB")}
            if(message.isNotBlank()) Text(message)
            if(state.log.isNotBlank()) androidx.compose.foundation.text.selection.SelectionContainer { Text(state.log, style=MaterialTheme.typography.bodySmall) }
        }
    }, confirmButton={TextButton(onClick=onDismiss){Text("Close")}})
}
