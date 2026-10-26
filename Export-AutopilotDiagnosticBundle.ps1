<#
.SYNOPSIS
    Collects MdmDiagnosticsTool output, Intune Management Extension logs, and Event Viewer logs into a single ZIP.
.DESCRIPTION
    Automates log gathering during or after Windows Autopilot provisioning so administrators can extract
    a single diagnostic package for root-cause analysis.
.PARAMETER OutputDirectory
    Target folder where the final ZIP bundle will be saved. Defaults to C:\Temp.
.EXAMPLE
    .\Export-AutopilotDiagnosticBundle.ps1 -OutputDirectory "C:\Temp"
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "C:\Temp"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$computer = $env:COMPUTERNAME
$stagingDir = Join-Path $env:TEMP "AdminSignal-AutopilotDiag-$timestamp"
$finalZip = Join-Path $OutputDirectory "AdminSignal-AutopilotDiag-$computer-$timestamp.zip"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

Write-Host "[+] Staging diagnostic collection in $stagingDir..." -ForegroundColor Cyan

# 1. Run MdmDiagnosticsTool
$mdmZip = Join-Path $stagingDir "MdmDiagnosticsTool-Autopilot.zip"
Write-Host "[1/4] Running MdmDiagnosticsTool.exe (Autopilot;TPM;DeviceEnrollment;DeviceProvisioning)..." -ForegroundColor Yellow
Start-Process -FilePath "MdmDiagnosticsTool.exe" -ArgumentList "-area `"Autopilot;TPM;DeviceEnrollment;DeviceProvisioning`" -zip `"$mdmZip`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue

# 2. Copy Intune Management Extension (IME) Logs
$imeLogDir = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$imeStaging = Join-Path $stagingDir "IME-Logs"
if (Test-Path $imeLogDir) {
    Write-Host "[2/4] Copying Intune Management Extension logs..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $imeStaging -Force | Out-Null
    Copy-Item -Path "$imeLogDir\*.log" -Destination $imeStaging -Force -ErrorAction SilentlyContinue
}

# 3. Export key Event Viewer channels
$evtxStaging = Join-Path $stagingDir "EventLogs"
New-Item -ItemType Directory -Path $evtxStaging -Force | Out-Null
Write-Host "[3/4] Exporting Autopilot & DeviceManagement Event Logs..." -ForegroundColor Yellow

$channels = @{
    "DeviceManagement-Admin.evtx"       = "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin"
    "DeviceManagement-Operational.evtx" = "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational"
    "Autopilot.evtx"                    = "Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot"
    "ManagementService.evtx"            = "Microsoft-Windows-ModernDeployment-Diagnostics-Provider/ManagementService"
}

foreach ($file in $channels.Keys) {
    $outFile = Join-Path $evtxStaging $file
    wevtutil.exe epl $channels[$file] "$outFile" /ow:true 2>$null
}

# 4. Compress final bundle
Write-Host "[4/4] Compressing diagnostic bundle to $finalZip..." -ForegroundColor Yellow
if (Test-Path $finalZip) { Remove-Item $finalZip -Force }
Compress-Archive -Path "$stagingDir\*" -DestinationPath $finalZip -Force
Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n[+] Diagnostic bundle created: $finalZip" -ForegroundColor Green
