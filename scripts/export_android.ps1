$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Profile = Join-Path $ProjectRoot '.godot-profile'
$env:APPDATA = Join-Path $Profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $Profile 'Local'
$LocalJdk = Join-Path $ProjectRoot '.tools\jdk-17'
$env:JAVA_HOME = if (Test-Path -LiteralPath (Join-Path $LocalJdk 'bin\java.exe')) { $LocalJdk } else { $env:JAVA_HOME }
$env:ANDROID_HOME = Join-Path $Profile 'Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$Godot = Join-Path $ProjectRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$SdkPath = $env:ANDROID_HOME
$Problems = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $Godot)) { $Problems.Add('Godot 4.7.2 console editor is missing. Run scripts\arcanist.ps1 Setup.') }
$Java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { '' }
if (-not $Java -or -not (Test-Path -LiteralPath $Java)) { $Problems.Add('OpenJDK 17 is missing. Run scripts\arcanist.ps1 SetupAndroid.') }
else {
	$PreviousErrorActionPreference = $ErrorActionPreference
	try {
		$ErrorActionPreference = 'Continue'
		$JavaVersionText = (& $Java -version 2>&1 | Out-String)
	} finally {
		$ErrorActionPreference = $PreviousErrorActionPreference
	}
	if ($JavaVersionText -notmatch 'version "(1[7-9]|[2-9][0-9])\.') { $Problems.Add('Android export requires JDK 17 or newer.') }
}
$SdkManager = Join-Path $SdkPath 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path -LiteralPath (Join-Path $SdkPath 'platform-tools\adb.exe'))) { $Problems.Add('Android SDK platform-tools are missing. Run scripts\arcanist.ps1 SetupAndroid.') }
if (-not (Test-Path -LiteralPath $SdkManager)) { $Problems.Add('Android SDK command-line tools are missing. Run scripts\arcanist.ps1 SetupAndroid.') }
$Required = @(
    'build-tools\35.0.1\aapt.exe',
    'build-tools\35.0.1\apksigner.bat',
    'platforms\android-35\android.jar',
    'cmake\3.10.2.4988404\bin\cmake.exe',
    'ndk\28.1.13356709\source.properties'
)
foreach ($RelativePath in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $SdkPath $RelativePath))) { $Problems.Add("Android SDK package missing: $RelativePath") }
}
if (-not (Test-Path -LiteralPath (Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable\android_debug.apk'))) { $Problems.Add('Android export template is missing. Run scripts\arcanist.ps1 Setup.') }
if (-not (Test-Path -LiteralPath (Join-Path $env:APPDATA 'Godot\keystores\debug.keystore'))) { $Problems.Add('Local debug signing key is missing. Run scripts\arcanist.ps1 SetupAndroid.') }

if ($Problems.Count -gt 0) {
    Write-Error ('Android export is not configured:' + [Environment]::NewLine + ($Problems -join [Environment]::NewLine))
    exit 2
}

New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot 'build\android') | Out-Null
$ApkPath = Join-Path $ProjectRoot 'build\android\ProjectArcanist.apk'
& $Godot --headless --path $ProjectRoot --export-debug 'Android' $ApkPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $ApkPath)) { throw 'Godot completed without creating the expected Android APK.' }
$Aapt = Join-Path $SdkPath 'build-tools\35.0.1\aapt.exe'
$Badging = (& $Aapt dump badging $ApkPath 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw "aapt could not inspect the exported APK: $Badging" }
if ($Badging -notmatch "package: name='com\.projectarcanist\.game'" -or $Badging -notmatch "application-label:'Project Arcanist'") { throw "Exported APK metadata does not match the configured game name/package:`n$Badging" }
$ApkSigner = Join-Path $SdkPath 'build-tools\35.0.1\apksigner.bat'
& $ApkSigner verify --verbose $ApkPath
if ($LASTEXITCODE -ne 0) { throw 'APK signing verification failed.' }
Write-Output "Android APK: $ApkPath"
Write-Output "Android size: $([math]::Round((Get-Item -LiteralPath $ApkPath).Length / 1MB, 1)) MiB"
Write-Output 'Android package and display name inspected; debug signature verified.'
exit 0
