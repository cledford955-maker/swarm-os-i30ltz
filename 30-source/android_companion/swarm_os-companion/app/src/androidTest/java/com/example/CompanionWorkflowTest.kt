package com.example

import android.app.Application
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import com.example.ui.coderdroid.*
import com.example.data.config.SwarmConnection
import com.example.data.service.LocalLlamaEngine
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.Request
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class CompanionWorkflowTest {
    @get:Rule val compose = createComposeRule()
    private val app get() = ApplicationProvider.getApplicationContext<Application>()
    @Test fun monacoActuallyLoadsAndEditsOffline() {
        val file = File(app.cacheDir,"editor-test-${System.nanoTime()}.kt").apply { writeText("val answer = 42") }
        val changed = AtomicReference("")
        val tab = CdrEditorTab(fileNode=CdrFileNode(file))
        compose.setContent { CdrMonacoEditorView(tab, {_,content -> changed.set(content)}, {_,_->}) }
        val result=AtomicReference("false")
        fun find(view: View): WebView? = if(view is WebView) view else if(view is ViewGroup) (0 until view.childCount).firstNotNullOfOrNull { find(view.getChildAt(it)) } else null
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        fun evaluate(code: String) {
            instrumentation.runOnMainSync {
                val activity=ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(Stage.RESUMED).firstOrNull()
                activity?.let { find(it.window.decorView)?.evaluateJavascript(code) { result.set(it) } }
            }
        }
        val deadline=System.currentTimeMillis()+30000
        while(System.currentTimeMillis()<deadline) {
            evaluate("typeof window.coderdroid !== 'undefined' && monaco.editor.getModels().some(m => m.getValue() === 'val answer = 42')")
            if(result.get()=="true") break
            Thread.sleep(200)
        }
        assertEquals("Monaco should load its bundled assets and file", "true",result.get())
        evaluate("window.coderdroid.insertSnippet('// phone edit\\n')")
        compose.waitUntil(10000) { changed.get().contains("phone edit") }
        file.delete()
    }
    @Test fun connectionUsesSavedCredentialsAndRealHost() {
        val c=SwarmConnection(app)
        val request=Request.Builder().url(c.httpBase()+"/api/android/capabilities").header("X-Swarm-Auth",c.authToken).build()
        OkHttpClient().newCall(request).execute().use { assertEquals(200,it.code); assertTrue(it.body!!.string().contains("sdkAvailable")) }
    }
    @Test fun unavailableOfflineModelDoesNotInventSuccess() = runBlocking {
        val engine=LocalLlamaEngine()
        assertFalse(engine.initializeModel())
        assertFalse(engine.isLoaded())
        assertTrue(engine.generateLocalResponse("repair grub","").contains("unavailable"))
    }
    @Test fun createBuildAndDownloadRealAndroidApp() {
        val model=AndroidToolsViewModel(app)
        val name="CompanionSmoke"+System.currentTimeMillis()
        val root=AtomicReference<File?>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.createProject(name,"com.i30ltz.companion.smoketest") {root.set(it)} }
        val createdDeadline=System.currentTimeMillis()+15000
        while(root.get()==null && System.currentTimeMillis()<createdDeadline) Thread.sleep(100)
        assertNotNull(model.state.value.status,root.get())
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.build(root.get()!!) }
        val buildDeadline=System.currentTimeMillis()+10*60*1000
        while(model.state.value.busy && System.currentTimeMillis()<buildDeadline) Thread.sleep(1000)
        assertTrue(model.state.value.status+"\n"+model.state.value.log,model.state.value.built)
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.download() }
        val downloadDeadline=System.currentTimeMillis()+60000
        while(model.state.value.busy && System.currentTimeMillis()<downloadDeadline) Thread.sleep(200)
        val apk=model.state.value.apk
        assertNotNull(model.state.value.status,apk)
        assertNotNull(app.packageManager.getPackageArchiveInfo(apk!!.path,0))
        // Leave this uniquely named sample and APK available for a manual install check.
    }
}
