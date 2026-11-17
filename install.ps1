# Instala DocxViewer para el usuario actual (no necesita administrador).
# - Aparece en "Abrir con" de los .docx y .doc
# - Aparece en Configuracion > Aplicaciones > Aplicaciones predeterminadas
# - Aparece en Aplicaciones instaladas y en el menu Inicio

$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$exe = Join-Path $dir 'DocxViewer.exe'
$ico = Join-Path $dir 'DocxViewer.ico'

if (-not (Test-Path $exe)) { throw "No se encuentra DocxViewer.exe en $dir" }

$progId   = 'DocxViewer.Document'
$oldProg  = 'DocxViewer.docx'
$exts     = @('.docx', '.doc')
$openCmd  = '"' + $exe + '" "%1"'
$typeName = 'Documento de Word (DocxViewer)'

Write-Host "Instalando DocxViewer..." -ForegroundColor Cyan

# ---------- ProgID ----------
$progKey = "HKCU:\Software\Classes\$progId"
New-Item -Path $progKey -Force | Out-Null
Set-ItemProperty -Path $progKey -Name '(default)' -Value $typeName
New-ItemProperty -Path $progKey -Name 'FriendlyTypeName' -Value $typeName -PropertyType String -Force | Out-Null

$appKey = "$progKey\Application"
New-Item -Path $appKey -Force | Out-Null
Set-ItemProperty -Path $appKey -Name 'ApplicationName' -Value 'DocxViewer'
Set-ItemProperty -Path $appKey -Name 'ApplicationIcon' -Value ($exe + ',0')
Set-ItemProperty -Path $appKey -Name 'ApplicationDescription' -Value 'Visor ligero de documentos .docx y .doc'

$iconKey = "$progKey\DefaultIcon"
New-Item -Path $iconKey -Force | Out-Null
Set-ItemProperty -Path $iconKey -Name '(default)' -Value ($exe + ',0')

$cmdKey = "$progKey\shell\open\command"
New-Item -Path $cmdKey -Force | Out-Null
Set-ItemProperty -Path $cmdKey -Name '(default)' -Value $openCmd

# ---------- aparecer en "Abrir con" ----------
foreach ($ext in $exts) {
    $owp = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\$ext\OpenWithProgids")
    $owp.SetValue($progId, [byte[]]@(), [Microsoft.Win32.RegistryValueKind]::None)
    $owp.Close()
}

# ---------- limpiar el ProgID anterior (solo .docx) ----------
$oldKey = "HKCU:\Software\Classes\$oldProg"
if (Test-Path $oldKey) { Remove-Item -Path $oldKey -Recurse -Force -ErrorAction SilentlyContinue }
try {
    $owpOld = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\.docx\OpenWithProgids', $true)
    if ($owpOld) { $owpOld.DeleteValue($oldProg, $false); $owpOld.Close() }
} catch { }

# ---------- aparecer en "Aplicaciones predeterminadas" ----------
$capKey = 'HKCU:\Software\DocxViewer\Capabilities'
New-Item -Path $capKey -Force | Out-Null
Set-ItemProperty -Path $capKey -Name 'ApplicationName' -Value 'DocxViewer'
Set-ItemProperty -Path $capKey -Name 'ApplicationDescription' -Value 'Visor ligero de documentos .docx y .doc (sin Office)'
Set-ItemProperty -Path $capKey -Name 'ApplicationIcon' -Value ($exe + ',0')

$faKey = "$capKey\FileAssociations"
New-Item -Path $faKey -Force | Out-Null
foreach ($ext in $exts) {
    Set-ItemProperty -Path $faKey -Name $ext -Value $progId
}

New-ItemProperty -Path 'HKCU:\Software\RegisteredApplications' -Name 'DocxViewer' -Value 'Software\DocxViewer\Capabilities' -PropertyType String -Force | Out-Null

# ---------- aparecer en "Aplicaciones instaladas" ----------
$unKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DocxViewer'
New-Item -Path $unKey -Force | Out-Null
Set-ItemProperty -Path $unKey -Name 'DisplayName' -Value 'DocxViewer'
Set-ItemProperty -Path $unKey -Name 'DisplayVersion' -Value '1.3.0'
Set-ItemProperty -Path $unKey -Name 'Publisher' -Value 'Local'
Set-ItemProperty -Path $unKey -Name 'DisplayIcon' -Value ($exe + ',0')
Set-ItemProperty -Path $unKey -Name 'InstallLocation' -Value $dir
Set-ItemProperty -Path $unKey -Name 'UninstallString' -Value ('"' + (Join-Path $dir 'uninstall.cmd') + '"')
New-ItemProperty -Path $unKey -Name 'NoModify' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $unKey -Name 'NoRepair' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $unKey -Name 'EstimatedSize' -Value ([int]((Get-ChildItem $dir -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)) -PropertyType DWord -Force | Out-Null

# ---------- acceso directo en el menu Inicio ----------
try {
    $startDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'DocxViewer'
    New-Item -ItemType Directory -Path $startDir -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path $startDir 'DocxViewer.lnk'))
    $lnk.TargetPath = $exe
    $lnk.WorkingDirectory = $dir
    $lnk.IconLocation = $exe + ',0'
    $lnk.Description = 'Visor de documentos .docx y .doc'
    $lnk.Save()
} catch {
    Write-Host "Aviso: no se pudo crear el acceso directo del menu Inicio ($($_.Exception.Message))" -ForegroundColor Yellow
}

# ---------- refrescar iconos / shell ----------
try { & ie4uinit.exe -show } catch { }

Write-Host ""
Write-Host "Listo. DocxViewer ya esta registrado para .docx y .doc." -ForegroundColor Green
Write-Host ""
Write-Host "Para usarlo como predeterminado:" -ForegroundColor Cyan
Write-Host "  Clic derecho en un .docx (o .doc)  >  Abrir con  >  Elegir otra aplicacion"
Write-Host "  >  DocxViewer  >  marcar 'Usar siempre para abrir...'"
Write-Host ""
Write-Host "Tambien: Configuracion > Aplicaciones > Aplicaciones predeterminadas > DocxViewer"
Write-Host ""
Write-Host ("Instalado en: {0}" -f $dir) -ForegroundColor DarkGray
