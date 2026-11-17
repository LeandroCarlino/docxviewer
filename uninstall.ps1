# Desinstala el registro de DocxViewer (los archivos no se borran).
$ErrorActionPreference = 'Continue'
$progIds = @('DocxViewer.Document', 'DocxViewer.docx')
$exts = @('.docx', '.doc')

Write-Host "Quitando registro de DocxViewer..." -ForegroundColor Cyan

foreach ($id in $progIds) {
    $key = "HKCU:\Software\Classes\$id"
    if (Test-Path $key) { Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue }
}

foreach ($key in @(
    'HKCU:\Software\DocxViewer',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DocxViewer'
)) {
    if (Test-Path $key) { Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue }
}

# quitar del menu "Abrir con"
foreach ($ext in $exts) {
    try {
        $owp = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Software\Classes\$ext\OpenWithProgids", $true)
        if ($owp) {
            foreach ($id in $progIds) { $owp.DeleteValue($id, $false) }
            $owp.Close()
        }
    } catch { }
}

# quitar de aplicaciones predeterminadas
try {
    $ra = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\RegisteredApplications', $true)
    if ($ra) { $ra.DeleteValue('DocxViewer', $false); $ra.Close() }
} catch { }

# acceso directo del menu Inicio
try {
    $startDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'DocxViewer'
    if (Test-Path $startDir) { Remove-Item $startDir -Recurse -Force }
} catch { }

try { & ie4uinit.exe -show } catch { }

Write-Host "Hecho. DocxViewer ya no aparece en Windows (la carpeta con el programa sigue aqui)." -ForegroundColor Green
