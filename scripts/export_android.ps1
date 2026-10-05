$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Profile = Join-Path $ProjectRoot '.godot-profile'
$env:APPDATA = Join-Path $Profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $Profile 'Local'
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$SdkPath = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
$Problems = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $Godot)) { $Problems.Add("Godot 4.7.2 console editor is missing. Run scripts\arcanist.ps1 Setup.") }
if (-not $env:JAVA_HOME) {
    $Problems.Add('Set JAVA_HOME to OpenJDK 17 or a newer supported JDK.')
} else {
    $Java = Join-Path $env:JAVA_HOME 'bin\java.exe'
    if (-not (Test-Path -LiteralPath $Java)) { $Problems.Add("JAVA_HOME does not contain bin\java.exe: $env:JAVA_HOME") }
    elseif ((& $Java -version 2>&1 | Out-String) -notmatch 'version "(1[7-9]|[2-9][0-9])\.') { $Problems.Add('Android export requires JDK 17 or newer.') }
}
if (-not $SdkPath -or -not (Test-Path -LiteralPath (Join-Path $SdkPath 'platform-tools\adb.exe'))) {
    $Problems.Add('Set ANDROID_HOME (or ANDROID_SDK_ROOT) to an installed Android SDK that contains platform-tools\adb.exe.')
} else {
    $Required = @(
        'build-tools\35.0.1\aapt.exe',
        'platforms\android-35\android.jar',
        'cmake\3.10.2.4988404\bin\cmake.exe',
        'ndk\28.1.13356709\source.properties'
    )
    foreach ($RelativePath in $Required) {
        if (-not (Test-Path -LiteralPath (Join-Path $SdkPath $RelativePath))) { $Problems.Add("Android SDK package missing: $RelativePath") }
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable\android_debug.apk'))) {
    $Problems.Add('Android export template is missing. Run scripts\arcanist.ps1 Setup.')
}

if ($Problems.Count -gt 0) {
    Write-Error ('Android export is not configured:' + [Environment]::NewLine + ($Problems -join [Environment]::NewLine))
    exit 2
}

New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot 'build\android') | Out-Null
& $Godot --headless --path $ProjectRoot --export-debug 'Android' 'build/android/ProjectArcanist.apk'
exit $LASTEXITCODE
