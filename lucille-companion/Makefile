# Lucille Companion — Android build  v1.0.0  2026-09-24
# Requires: Android SDK, JDK 17, ANDROID_HOME set
# Usage: make debug | make release | make install

.PHONY: debug release install clean lint help

VERSION     = 1.0.0
BUILD_DATE  = 2026-09-24
APK_DEBUG   = app/build/outputs/apk/debug/app-debug.apk
APK_RELEASE = app/build/outputs/apk/release/app-release.apk

help:
	@echo "Lucille Companion  v$(VERSION)  $(BUILD_DATE)"
	@echo ""
	@echo "  make debug    — Build debug APK"
	@echo "  make release  — Build release APK (requires keystore)"
	@echo "  make install  — Build + install to connected device"
	@echo "  make lint     — Run lint checks"
	@echo "  make clean    — Clean build artifacts"

debug:
	./gradlew assembleDebug
	@echo "✅ Debug APK: $(APK_DEBUG)"

release:
	./gradlew assembleRelease
	@echo "✅ Release APK: $(APK_RELEASE)"

install:
	./gradlew installDebug
	@echo "✅ Installed on device"
	adb shell am start -n com.swarm.lucille/.MainActivity

lint:
	./gradlew lint
	@echo "✅ Lint report: app/build/reports/lint-results-debug.html"

clean:
	./gradlew clean
	@echo "✅ Build artifacts cleaned"
