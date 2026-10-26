<#
.SYNOPSIS
    Pre-flight readiness check for Windows Autopilot hardware, TPM 2.0, WMI hardware hash, and network endpoints.
.DESCRIPTION
    Evaluates whether a Windows 10/11 endpoint is ready to be wiped/re-provisioned with Windows Autopilot.
    Checks TPM 2.0 availability, SMBIOS identity, MDM_DevDetail_Ext01 4K hardware hash accessibility,
    W32Time clock sync, and TCP 443 connectivity to required Microsoft Autopilot & Intune endpoints.
.EXAMPLE
    .\Test-AutopilotReadiness.ps1
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

[CmdletBinding()]
param()

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "       AdminSignal Windows Autopilot Pre-Flight Readiness        " -ForegroundColor Cyan
Write-Host "       https://adminsignal.com                                   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$checks = [System.Collections.Generic.List[PSCustomObject]]::new()

# 1. Check SMBIOS Serial & UUID
try {
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    $csProd = Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop
    $badSerial = [string]::IsNullOrWhiteSpace($bios.SerialNumber) -or ($bios.SerialNumber -match "O\.E\.M|Default|None|00000")
    $checks.Add([PSCustomObject]@{
        Category = "Hardware"
        Check    = "SMBIOS Serial & UUID"
        Status   = if (-not $badSerial) { "PASS" } else { "WARN" }
        Detail   = "Serial: $($bios.SerialNumber) | UUID: $($csProd.UUID)"
    })
} catch {
    $checks.Add([PSCustomObject]@{ Category = "Hardware"; Check = "SMBIOS Serial & UUID"; Status = "FAIL"; Detail = $_.Exception.Message })
}

# 2. Check TPM 2.0 State
try {
    $tpm = Get-Tpm -ErrorAction Stop
    $tpmWmi = Get-CimInstance -Namespace "root\cimv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    $specVer = if ($tpmWmi) { ($tpmWmi.SpecVersion -split ",")[0].Trim() } else { "Unknown" }
    $tpmOk = $tpm.TpmPresent -and $tpm.TpmReady -and ($specVer -eq "2.0")
    $checks.Add([PSCustomObject]@{
        Category = "TPM"
        Check    = "TPM 2.0 Present & Ready"
        Status   = if ($tpmOk) { "PASS" } else { "FAIL" }
        Detail   = "Present: $($tpm.TpmPresent) | Ready: $($tpm.TpmReady) | Spec: $specVer"
    })
} catch {
    $checks.Add([PSCustomObject]@{ Category = "TPM"; Check = "TPM 2.0 Present & Ready"; Status = "FAIL"; Detail = "Run as Administrator to query TPM ($($_.Exception.Message))" })
}

# 3. Check 4K Hardware Hash Availability in WMI
try {
    $devDetail = Get-CimInstance -Namespace "root/cimv2/mdm/dmmap" -ClassName "MDM_DevDetail_Ext01" -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" -ErrorAction Stop
    $hasHash = -not [string]::IsNullOrWhiteSpace($devDetail.DeviceHardwareData)
    $checks.Add([PSCustomObject]@{
        Category = "Autopilot"
        Check    = "4K Hardware Hash (MDM_DevDetail_Ext01)"
        Status   = if ($hasHash) { "PASS" } else { "FAIL" }
        Detail   = if ($hasHash) { "Hash retrievable (Length: $($devDetail.DeviceHardwareData.Length) chars)" } else { "Empty hardware hash" }
    })
} catch {
    $checks.Add([PSCustomObject]@{ Category = "Autopilot"; Check = "4K Hardware Hash (MDM_DevDetail_Ext01)"; Status = "FAIL"; Detail = "Unable to query MDM_DevDetail_Ext01 (Requires SYSTEM/Admin)" })
}

# 4. Check Windows Time Service
$w32time = Get-Service -Name W32Time -ErrorAction SilentlyContinue
$checks.Add([PSCustomObject]@{
    Category = "System"
    Check    = "Windows Time Service (W32Time)"
    Status   = if ($w32time.Status -eq "Running") { "PASS" } else { "WARN" }
    Detail   = "Service Status: $($w32time.Status) | Local Time: $(Get-Date -Format 'u')"
})

# 5. Check Required Autopilot & Intune Endpoints (TCP 443)
$endpoints = @(
    "ztd.dds.microsoft.com",
    "cs.dds.microsoft.com",
    "login.microsoftonline.com",
    "enterpriseregistration.windows.net",
    "manage.microsoft.com"
)

foreach ($hostName in $endpoints) {
    $reachable = $false
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($hostName, 443, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait -and $tcp.Connected) {
            $reachable = $true
        }
        $tcp.Close()
    } catch {}

    $checks.Add([PSCustomObject]@{
        Category = "Network"
        Check    = "TLS 443 -> $hostName"
        Status   = if ($reachable) { "PASS" } else { "FAIL" }
        Detail   = if ($reachable) { "Connected on TCP 443" } else { "Connection timed out or blocked" }
    })
}

Write-Host ""
$checks | Format-Table -AutoSize

$failed = @($checks | Where-Object { $_.Status -eq "FAIL" })
if ($failed.Count -gt 0) {
    Write-Host "[!] Readiness check finished with $($failed.Count) failure(s). Review before starting Autopilot reset." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[+] Endpoint passed all Windows Autopilot pre-flight checks!" -ForegroundColor Green
    exit 0
}
