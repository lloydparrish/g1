param([switch]$InstallTemplates)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$EngineDir = Join-Path $ProjectRoot '.tools\godot-4.7.2'
$StageDir = Join-Path $ProjectRoot '.tools\godot-4.7.2\setup-staging'
$EngineBase = 'https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable'
$Roaming = Join-Path $ProjectRoot '.godot-profile\Roaming'
$Local = Join-Path $ProjectRoot '.godot-profile\Local'
$TemplateDir = Join-Path $Roaming 'Godot\export_templates\4.7.2.stable'
New-Item -ItemType Directory -Force -Path $EngineDir,$StageDir,$Roaming,$Local | Out-Null

function Install-ZipFile([string]$FileName, [string]$EntryName) {
    $OutputPath = Join-Path $EngineDir $EntryName
    if (Test-Path -LiteralPath $OutputPath) { return }
    $ZipPath = Join-Path $StageDir $FileName
    $ExtractPath = Join-Path $StageDir ([guid]::NewGuid().ToString('N'))
    Invoke-WebRequest -Uri "$EngineBase/$FileName" -OutFile $ZipPath
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractPath -Force
    $Executable = Get-ChildItem -LiteralPath $ExtractPath -Filter $EntryName -Recurse | Select-Object -First 1
    if ($null -eq $Executable) { throw "The official Godot archive did not contain $EntryName." }
    Copy-Item -LiteralPath $Executable.FullName -Destination $OutputPath
    Remove-Item -LiteralPath $ZipPath -Force
    Remove-Item -LiteralPath $ExtractPath -Recurse -Force
}

Install-ZipFile 'Godot_v4.7.2-stable_win64.exe.zip' 'Godot_v4.7.2-stable_win64.exe'
Install-ZipFile 'Godot_v4.7.2-stable_win64_console.exe.zip' 'Godot_v4.7.2-stable_win64_console.exe'

if ($InstallTemplates -and -not (Test-Path -LiteralPath (Join-Path $TemplateDir 'android_debug.apk'))) {
    $ArchivePath = Join-Path $StageDir 'Godot_v4.7.2-stable_export_templates.tpz'
    Invoke-WebRequest -Uri "$EngineBase/Godot_v4.7.2-stable_export_templates.tpz" -OutFile $ArchivePath
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $TemplateDir | Out-Null
    $Archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $Entries = @(
            'templates/version.txt',
            'templates/windows_debug_x86_64.exe',
            'templates/windows_release_x86_64.exe',
            'templates/windows_debug_x86_64_console.exe',
            'templates/windows_release_x86_64_console.exe',
            'templates/android_debug.apk',
            'templates/android_release.apk'
        )
        foreach ($Name in $Entries) {
            $Entry = $Archive.GetEntry($Name)
            if ($null -eq $Entry) { throw "Missing Godot export template $Name." }
            $Destination = Join-Path $TemplateDir ([IO.Path]::GetFileName($Name))
            $InputStream = $Entry.Open()
            $OutputStream = [IO.File]::Create($Destination)
            try { $InputStream.CopyTo($OutputStream) }
            finally { $OutputStream.Dispose(); $InputStream.Dispose() }
        }
    }
    finally { $Archive.Dispose() }
    Remove-Item -LiteralPath $ArchivePath -Force
}

Write-Output "Godot 4.7.2 is ready at $EngineDir"
if ($InstallTemplates) { Write-Output "Windows and Android export templates are ready at $TemplateDir" }
