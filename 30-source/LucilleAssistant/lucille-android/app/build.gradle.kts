// Lucille Assistant — native Android companion  v1.0.0 · 2026-09-26
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace   = "os.swarm.lucille"
    compileSdk  = 35

    defaultConfig {
        applicationId = "os.swarm.lucille"
        minSdk        = 26
        targetSdk     = 35
        versionCode   = 1
        versionName   = "1.0.0"
    }

    buildTypes {
        debug   { applicationIdSuffix = ".debug"; versionNameSuffix = "-debug" }
        release { isMinifyEnabled = false }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures { compose = true }
}

dependencies {
    // Compose BOM — pins all compose versions together
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.tooling)
    implementation(libs.compose.icons)
    debugImplementation(libs.compose.tooling.d)

    // Navigation + lifecycle
    implementation(libs.nav.compose)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.compose)
    implementation(libs.activity.compose)

    // Coroutines
    implementation(libs.coroutines.core)
    implementation(libs.coroutines.android)

    // Serialization
    implementation(libs.serialization)

    // Network (OkHttp — no Retrofit, keeps it lean)
    implementation(libs.okhttp)

    // Image loading (avatar)
    implementation(libs.coil.compose)
}
