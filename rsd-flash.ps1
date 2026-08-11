# Moto RSD Lite - Flash Motorola RSD / fastboot XML packages on Windows
# Usage:
#   .\rsd-flash.ps1
#   .\rsd-flash.ps1 [firmware directory]
#   .\rsd-flash.ps1 [firmware directory] [XML file]
#   .\rsd-flash.ps1 [XML file]
#
# Or double-click rsd-flash.bat

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Arg1 = "",

    [Parameter(Position = 1)]
    [string]$Arg2 = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Reduce mojibake on Chinese Windows (CP936) consoles.
try {
    if ($Host.Name -eq 'ConsoleHost') {
        chcp 65001 > $null
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    }
} catch {}

$Fastboot = Join-Path $ScriptDir "files\fastboot.exe"
$Adb = Join-Path $ScriptDir "files\adb.exe"
$Version = "Windows"
$PackageDir = ""
$XmlFile = ""

function Show-Logo {
    Write-Host '     _  _     ____  _____ ____    ___  ____ ____    __   _  _____ ___     '
    Write-Host '   \/ \/ \  / _  \/_  _// _  \  / _ \/ __// _  \  / /  /_//_  _// _/      '
    Write-Host '  / ,  , \ / |_|  / /  / |_|   / , _\__ \/ // /  / /__/ / / /  / _/       '
    Write-Host ' /_/ \/ \_\____//_/   \____/  /_/|_/___//____/  /____/_//_/   \___/       '
    Write-Host (' ' * 69) -NoNewline
    Write-Host 'By LuoJuly' -ForegroundColor DarkGray
}

function Resolve-UserPath([string]$PathText) {
    if ([string]::IsNullOrWhiteSpace($PathText)) { return $PathText }
    $p = $PathText.Trim()
    if (($p.StartsWith("'") -and $p.EndsWith("'")) -or ($p.StartsWith('"') -and $p.EndsWith('"'))) {
        $p = $p.Substring(1, $p.Length - 2)
    }
    if ($p.StartsWith("~")) {
        $p = Join-Path $env:USERPROFILE $p.Substring(1).TrimStart('\', '/')
    }
    try {
        return (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
    } catch {
        return $p
    }
}

function Get-XmlLabel([string]$Path) {
    $base = [System.IO.Path]::GetFileName($Path)
    switch ($base.ToLowerInvariant()) {
        "flashfile.xml" { return "$base (Erase Data !!!)" }
        "servicefile.xml" { return "$base (Update Only)" }
        default { return $base }
    }
}

function Get-PackageXmlFiles([string]$Dir) {
    $files = @()
    $files += Get-ChildItem -LiteralPath $Dir -Filter "*.xml" -File -ErrorAction SilentlyContinue
    $files += Get-ChildItem -LiteralPath $Dir -Filter "*.XML" -File -ErrorAction SilentlyContinue
    return $files | Sort-Object FullName -Unique
}

function Prompt-PackageDir {
    Write-Host "----------------------------------------------------------------------------"
    Write-Host "Select flash package directory"
    Write-Host "  - Press Enter to use current tool folder:"
    Write-Host "    $ScriptDir"
    Write-Host "  - Or type/paste a path to the Motorola firmware folder"
    Write-Host "----------------------------------------------------------------------------"
    $inputDir = Read-Host "Package directory"
    if ([string]::IsNullOrWhiteSpace($inputDir)) {
        $script:PackageDir = $ScriptDir
    } else {
        $script:PackageDir = Resolve-UserPath $inputDir
    }
    if (-not (Test-Path -LiteralPath $script:PackageDir -PathType Container)) {
        throw "Directory not found: $($script:PackageDir)"
    }
}

function Pick-XmlInteractive {
    $xmls = @(Get-PackageXmlFiles $PackageDir)
    if ($xmls.Count -eq 0) {
        throw "No .xml flash file found in: $PackageDir"
    }

    if ($xmls.Count -eq 1) {
        $script:XmlFile = $xmls[0].FullName
        Write-Host "[*] Found XML: $(Get-XmlLabel $script:XmlFile)"
        $ans = Read-Host "Use this file? [Y/n]"
        if ($ans -match '^(n|no)$') { throw "Aborted." }
        return
    }

    Write-Host "----------------------------------------------------------------------------"
    Write-Host "Select XML flash file in:"
    Write-Host "  $PackageDir"
    Write-Host "----------------------------------------------------------------------------"
    for ($i = 0; $i -lt $xmls.Count; $i++) {
        Write-Host ("  {0,2}) {1}" -f ($i + 1), (Get-XmlLabel $xmls[$i].FullName))
    }
    Write-Host "----------------------------------------------------------------------------"
    $choice = Read-Host ("Enter number [1-{0}]" -f $xmls.Count)
    $n = 0
    if (-not [int]::TryParse($choice, [ref]$n) -or $n -lt 1 -or $n -gt $xmls.Count) {
        throw "Invalid selection."
    }
    $script:XmlFile = $xmls[$n - 1].FullName
}

function Resolve-Args {
    if ([string]::IsNullOrWhiteSpace($Arg1)) {
        Prompt-PackageDir
        Pick-XmlInteractive
        return
    }

    $a1 = Resolve-UserPath $Arg1
    if (Test-Path -LiteralPath $a1 -PathType Container) {
        $script:PackageDir = $a1
        if ([string]::IsNullOrWhiteSpace($Arg2)) {
            Pick-XmlInteractive
            return
        }
        $a2 = $Arg2.Trim().Trim("'", '"')
        if (Test-Path -LiteralPath $a2 -PathType Leaf) {
            $script:XmlFile = (Resolve-Path -LiteralPath $a2).Path
        } elseif (Test-Path -LiteralPath (Join-Path $PackageDir $a2) -PathType Leaf) {
            $script:XmlFile = (Resolve-Path -LiteralPath (Join-Path $PackageDir $a2)).Path
        } else {
            Write-Host "[-] XML not found: $Arg2"
            Write-Host "[*] Pick XML interactively..."
            Pick-XmlInteractive
        }
        return
    }

    if (Test-Path -LiteralPath $a1 -PathType Leaf) {
        $script:XmlFile = (Resolve-Path -LiteralPath $a1).Path
        $script:PackageDir = Split-Path -Parent $script:XmlFile
        return
    }

    $rel = Join-Path $ScriptDir $Arg1
    if (Test-Path -LiteralPath $rel -PathType Leaf) {
        $script:XmlFile = (Resolve-Path -LiteralPath $rel).Path
        $script:PackageDir = $ScriptDir
        return
    }

    Write-Host "[-] Not found: $Arg1"
    Write-Host "[*] Falling back to interactive selection..."
    Prompt-PackageDir
    Pick-XmlInteractive
}

function Get-AttrValue([string]$Line, [string]$Name) {
    $m = [regex]::Match($Line, $Name + '="([^"]*)"')
    if (-not $m.Success) { return "" }
    $val = $m.Groups[1].Value
    if ($val -match '\s') { return "" }
    return $val
}

function Get-FileMd5([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLowerInvariant()
}

function Write-Red([string]$Message) {
    Write-Host $Message -ForegroundColor Red
}

function Add-FlashError {
    param(
        [string]$Message,
        [switch]$Quiet
    )
    if (-not $Quiet) {
        Write-Red $Message
    }
    if ($script:FlashErrors -notcontains $Message) {
        $script:FlashErrors += $Message
    }
}

# fastboot writes normal progress/getvar output to stderr. With
# $ErrorActionPreference=Stop, capturing 2>&1 turns those lines into
# terminating ErrorRecords. Temporarily Continue around the native call.
function Invoke-FastbootCommand([string[]]$FbArgs) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $fbRaw = & $Fastboot @FbArgs 2>&1
        $fbRc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }

    $fbLines = @()
    foreach ($item in @($fbRaw)) {
        if ($null -eq $item) { continue }
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            $s = $item.ToString()
        } else {
            $s = [string]$item
        }
        if ($s.Length -eq 0) { continue }
        $fbLines += $s
    }

    return @{
        ExitCode = $fbRc
        Lines    = $fbLines
        Text     = ($fbLines -join "`n")
    }
}

function Invoke-Flash {
    if (-not (Test-Path -LiteralPath $Fastboot -PathType Leaf)) {
        throw "fastboot not found: $Fastboot"
    }
    if (-not (Test-Path -LiteralPath $XmlFile -PathType Leaf)) {
        throw "XML file not found: $XmlFile"
    }

    Write-Host "----------------------------------------------------------------------------"
    Write-Host "Package dir : $PackageDir"
    Write-Host "XML file    : $XmlFile"
    Write-Host "Platform    : $Version"
    Write-Host "----------------------------------------------------------------------------"
    # ASCII hyphen only - em dash becomes mojibake on CP936 consoles.
    Write-Host "Welcome to Moto RSD Lite For Windows, Mac and Linux - press Enter to start your flash"
    Write-Host "----------------------------------------------------------------------------"
    [void](Read-Host)

    Set-Location -LiteralPath $PackageDir
    $env:Path = "$(Join-Path $ScriptDir 'files');$env:Path"

    $script:FlashErrors = @()
    $lines = Get-Content -LiteralPath $XmlFile
    foreach ($line in $lines) {
        if ($line -notmatch 'step[^s]') { continue }
        if ($line -notmatch '<step\b') { continue }

        $md5 = Get-AttrValue $line "MD5"
        $file = Get-AttrValue $line "filename"
        $op = Get-AttrValue $line "operation"
        $part = Get-AttrValue $line "partition"
        $var = Get-AttrValue $line "var"

        if ($md5 -and $file) {
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
                Add-FlashError "$file`: file not found in $PackageDir"
                break
            }
            $fileMd5 = Get-FileMd5 $file
            if ($md5.ToLowerInvariant() -ne $fileMd5) {
                Add-FlashError "$file`: MD5 mismatch (expected $md5, got $fileMd5)."
                break
            }
        }

        $fbArgs = @()
        if ($op) { $fbArgs += $op }
        if ($part) { $fbArgs += $part }
        if ($file) { $fbArgs += $file }
        if ($var) { $fbArgs += $var }

        Write-Host (">> fastboot {0}" -f ($fbArgs -join ' '))
        $fb = Invoke-FastbootCommand $fbArgs
        foreach ($s in $fb.Lines) {
            if ($s -match '(?i)FAILED|error:') {
                Write-Red $s
            } else {
                Write-Host $s
            }
        }

        $fbBad = ($fb.ExitCode -ne 0) -or ($fb.Text -match '(?i)(^|\s)FAILED(\s|$)|error:')
        if ($fbBad) {
            Add-FlashError ("fastboot failed: {0} (exit {1})" -f ($fbArgs -join ' '), $fb.ExitCode)
            foreach ($eline in $fb.Lines) {
                if ($eline -match '(?i)FAILED|error:') {
                    Add-FlashError -Quiet $eline
                }
            }
            break
        }
    }

    Write-Host "---------------------------------------------------------"
    if ($script:FlashErrors.Count -eq 0) {
        Write-Host "Congratulations, no flashing errors found. Please press Enter to reboot device."
    } else {
        Write-Host "Please check for errors then press Enter to reboot device"
        Write-Host ("Error summary ({0}):" -f $script:FlashErrors.Count)
        foreach ($eline in $script:FlashErrors) {
            Write-Red ("  - {0}" -f $eline)
        }
    }
    Write-Host "---------------------------------------------------------"
    [void](Read-Host)
    $null = Invoke-FastbootCommand @("reboot")
}

try {
    Show-Logo
    Resolve-Args
    Invoke-Flash
} catch {
    Write-Host "[-] $_" -ForegroundColor Red
    Write-Host "Press Enter to exit..."
    [void](Read-Host)
    exit 1
}
