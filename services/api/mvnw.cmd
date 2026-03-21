@REM Maven Wrapper script for Windows CMD
@echo off

set MAVEN_PROJECTBASEDIR=%~dp0
set MAVEN_WRAPPER_JAR=%MAVEN_PROJECTBASEDIR%.mvn\wrapper\maven-wrapper.jar

@REM Find JAVA_HOME
if not defined JAVA_HOME (
    if exist "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot" (
        set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
    )
)

if defined JAVA_HOME (
    set "JAVACMD=%JAVA_HOME%\bin\java.exe"
) else (
    set "JAVACMD=java.exe"
)

if not exist "%MAVEN_WRAPPER_JAR%" (
    echo Error: Maven wrapper JAR not found
    exit /b 1
)

"%JAVACMD%" -jar "%MAVEN_WRAPPER_JAR%" %*
