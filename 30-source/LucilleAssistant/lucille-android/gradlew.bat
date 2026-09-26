@rem Gradle startup script for Windows
@if "%DEBUG%"=="" @echo off
set DIRNAME=%~dp0
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%
set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar
java %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*
