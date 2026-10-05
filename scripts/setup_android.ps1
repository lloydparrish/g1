param(
    [switch]$SkipSdkPackages
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ToolRoot = Join-Path $ProjectRoot '.tools'
$JdkPath = Join-Path $ToolRoot 'jdk-17'
$Profile = Join-Path $ProjectRoot '.godot-profile'
$SdkPath = Join-Path $Profile 'Local\Android\Sdk'
$AppDataRoot = Join-Path $Profile 'Roaming'
$CliArchive = 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
$CliSha256 = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'

New-Item -ItemType Directory -Force -Path $ToolRoot, $SdkPath, $AppDataRoot | Out-Null

if (-not (Test-Path -LiteralPath (Join-Path $JdkPath 'bin\java.exe'))) {
    $JdkArchive = Join-Path $ToolRoot 'temurin-17-windows-x64.zip'
    $JdkExtract = Join-Path $ToolRoot 'jdk-17-extract'
    Write-Output 'Downloading project-local Eclipse Temurin JDK 17...'
    Invoke-WebRequest -Uri 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse' -OutFile $JdkArchive -TimeoutSec 1800
    if (Test-Path -LiteralPath $JdkExtract) { Remove-Item -LiteralPath $JdkExtract -Recurse -Force }
    Expand-Archive -LiteralPath $JdkArchive -DestinationPath $JdkExtract -Force
    $JdkDirectory = Get-ChildItem -LiteralPath $JdkExtract -Directory | Select-Object -First 1
    if (-not $JdkDirectory -or -not (Test-Path -LiteralPath (Join-Path $JdkDirectory.FullName 'bin\java.exe'))) { throw 'Temurin archive did not contain a JDK.' }
    if (Test-Path -LiteralPath $JdkPath) { Remove-Item -LiteralPath $JdkPath -Recurse -Force }
    Move-Item -LiteralPath $JdkDirectory.FullName -Destination $JdkPath
    Remove-Item -LiteralPath $JdkExtract -Recurse -Force
}

$Java = Join-Path $JdkPath 'bin\java.exe'
$JavaVersionText = (& $Java -version 2>&1 | Out-String)
if ($JavaVersionText -notmatch 'version "17\.') { throw "Project-local Java must be JDK 17; found:`n$JavaVersionText" }
$env:JAVA_HOME = $JdkPath
$env:Path = (Join-Path $JdkPath 'bin') + ';' + $env:Path

$CmdlineRoot = Join-Path $SdkPath 'cmdline-tools'
$BootstrapManager = Join-Path $CmdlineRoot 'bootstrap\bin\sdkmanager.bat'
if (-not (Test-Path -LiteralPath $BootstrapManager)) {
	$ExistingManager = Join-Path $CmdlineRoot 'latest\bin\sdkmanager.bat'
	if (Test-Path -LiteralPath $ExistingManager) {
		Move-Item -LiteralPath (Join-Path $CmdlineRoot 'latest') -Destination (Join-Path $CmdlineRoot 'bootstrap')
	} else {
    $CliArchivePath = Join-Path $ToolRoot 'android-commandlinetools-win-15859902.zip'
    $CliExtract = Join-Path $ToolRoot 'android-cli-extract'
    Write-Output 'Downloading the official Android SDK command-line tools...'
    Invoke-WebRequest -Uri $CliArchive -OutFile $CliArchivePath -TimeoutSec 1800
    $ActualSha256 = (Get-FileHash -LiteralPath $CliArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualSha256 -ne $CliSha256) { throw "Android command-line tools checksum mismatch: $ActualSha256" }
    if (Test-Path -LiteralPath $CliExtract) { Remove-Item -LiteralPath $CliExtract -Recurse -Force }
    Expand-Archive -LiteralPath $CliArchivePath -DestinationPath $CliExtract -Force
    $ExtractedCli = Join-Path $CliExtract 'cmdline-tools'
    $LatestCli = Join-Path $CmdlineRoot 'bootstrap'
    New-Item -ItemType Directory -Force -Path (Split-Path $LatestCli -Parent) | Out-Null
    if (Test-Path -LiteralPath $LatestCli) { Remove-Item -LiteralPath $LatestCli -Recurse -Force }
    Move-Item -LiteralPath $ExtractedCli -Destination $LatestCli
    Remove-Item -LiteralPath $CliExtract -Recurse -Force
    }
}
$SdkManager = $BootstrapManager

if (-not $SkipSdkPackages) {
    $Packages = @(
        'platform-tools',
        'build-tools;35.0.1',
        'platforms;android-35',
        'cmdline-tools;latest',
        'cmake;3.10.2.4988404',
        'ndk;28.1.13356709'
    )
    Write-Output 'Accepting the Android SDK package licenses for this requested local toolchain...'
    1..100 | ForEach-Object { 'y' } | & $SdkManager "--sdk_root=$SdkPath" --licenses
    if ($LASTEXITCODE -ne 0) { throw 'Android SDK license setup failed.' }
    Write-Output 'Installing the Android packages required by Godot 4.7.2...'
    & $SdkManager "--sdk_root=$SdkPath" @Packages
    if ($LASTEXITCODE -ne 0) { throw 'Android SDK package installation failed.' }
}

$LatestManager = Join-Path $CmdlineRoot 'latest\bin\sdkmanager.bat'
if (-not (Test-Path -LiteralPath $LatestManager)) {
	$LatestPackage = Get-ChildItem -LiteralPath $CmdlineRoot -Directory -Filter 'latest-*' | Select-Object -First 1
	if ($LatestPackage) { Move-Item -LiteralPath $LatestPackage.FullName -Destination (Join-Path $CmdlineRoot 'latest') }
}
if (-not (Test-Path -LiteralPath $LatestManager)) { throw 'The Android SDK command-line tools package did not install into cmdline-tools\latest.' }

$DebugKeystore = Join-Path $AppDataRoot 'Godot\keystores\debug.keystore'
if (-not (Test-Path -LiteralPath $DebugKeystore)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $DebugKeystore -Parent) | Out-Null
    $Keytool = Join-Path $JdkPath 'bin\keytool.exe'
    & $Keytool -genkeypair -keystore $DebugKeystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 -dname 'CN=Android Debug,O=Android,C=US' -noprompt
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the local Godot debug keystore.' }
}

$env:APPDATA = $AppDataRoot
$env:LOCALAPPDATA = Join-Path $Profile 'Local'
$SettingsPath = Join-Path $AppDataRoot 'Godot\editor_settings-4.7.tres'
$SettingsDirectory = Split-Path $SettingsPath -Parent
New-Item -ItemType Directory -Force -Path $SettingsDirectory | Out-Null
if (Test-Path -LiteralPath $SettingsPath) {
    $Settings = Get-Content -LiteralPath $SettingsPath -Raw
} else {
    $Settings = '[gd_resource type="EditorSettings" format=3]' + [Environment]::NewLine + [Environment]::NewLine + '[resource]' + [Environment]::NewLine
}
$JdkSetting = 'export/android/java_sdk_path = "' + $JdkPath.Replace('\', '/') + '"'
$SdkSetting = 'export/android/android_sdk_path = "' + $SdkPath.Replace('\', '/') + '"'
if ($Settings -match '(?m)^export/android/java_sdk_path\s*=.*$') { $Settings = [regex]::Replace($Settings, '(?m)^export/android/java_sdk_path\s*=.*$', $JdkSetting) } else { $Settings += $JdkSetting + [Environment]::NewLine }
if ($Settings -match '(?m)^export/android/android_sdk_path\s*=.*$') { $Settings = [regex]::Replace($Settings, '(?m)^export/android/android_sdk_path\s*=.*$', $SdkSetting) } else { $Settings += $SdkSetting + [Environment]::NewLine }
if ($Settings -notmatch '(?m)^export/android/debug_keystore\s*=') { $Settings += 'export/android/debug_keystore = "' + $DebugKeystore.Replace('\', '/') + '"' + [Environment]::NewLine }
if ($Settings -notmatch '(?m)^export/android/debug_keystore_pass\s*=') { $Settings += 'export/android/debug_keystore_pass = "android"' + [Environment]::NewLine }
Set-Content -LiteralPath $SettingsPath -Value $Settings -Encoding utf8

$RequiredFiles = @(
    'platform-tools\adb.exe',
    'build-tools\35.0.1\aapt.exe',
    'build-tools\35.0.1\apksigner.bat',
    'platforms\android-35\android.jar',
    'cmake\3.10.2.4988404\bin\cmake.exe',
    'ndk\28.1.13356709\source.properties'
)
foreach ($RelativePath in $RequiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $SdkPath $RelativePath))) { throw "Android setup is incomplete: $RelativePath" }
}

Write-Output "Java: $($JavaVersionText.Trim())"
Write-Output "Android SDK: $SdkPath"
Write-Output "Godot editor settings: $SettingsPath"
Write-Output 'Run scripts\arcanist.ps1 Setup if the Godot 4.7.2 Android export template is not yet installed.'
