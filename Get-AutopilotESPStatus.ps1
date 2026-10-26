<#
.SYNOPSIS
    Inspects local Windows Autopilot profile settings, ESP progress, and IME Win32 app installation states.
.DESCRIPTION
    Designed to be run from an elevated prompt (or Shift + F10 during OOBE) to quickly pinpoint
    why the Enrollment Status Page (ESP) is waiting or which Win32 application failed to install.
.EXAMPLE
    .\Get-AutopilotESPStatus.ps1
.NOTES
    Author: AdminSignal (https://adminsignal.com)
#>

[CmdletBinding()]
param()

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "       AdminSignal Autopilot ESP & Win32 App Status Inspector    " -ForegroundColor Cyan
Write-Host "       https://adminsignal.com                                   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Read Autopilot Profile Cache
$apDiagPath = "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot"
if (Test-Path $apDiagPath) {
    $apProps = Get-ItemProperty -Path $apDiagPath -ErrorAction SilentlyContinue
    Write-Host "`n[+] Local Autopilot Profile Metadata:" -ForegroundColor Yellow
    [PSCustomObject]@{
        TenantDomain          = $apProps.CloudAssignedTenantDomain
        TenantId              = $apProps.CloudAssignedTenantId
        ZtdCorrelationId      = $apProps.ZtdCorrelationId
        DeploymentMode        = switch ($apProps.CloudAssignedDeploymentMode) { 0 { "User-Driven (0)" } 1 { "Self-Deploying (1)" } default { $apProps.CloudAssignedDeploymentMode } }
        DomainJoinMethod      = switch ($apProps.CloudAssignedDomainJoinMethod) { 0 { "Entra Joined (0)" } 1 { "Hybrid Entra Joined (1)" } default { $apProps.CloudAssignedDomainJoinMethod } }
        ForcedEnrollment      = $apProps.CloudAssignedForcedEnrollment
    } | Format-List
} else {
    Write-Host "`n[!] No Autopilot Diagnostics registry hive found at $apDiagPath." -ForegroundColor Yellow
}

# 2. Inspect IME Win32 App Tracking State
$imeWin32Path = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps"
if (Test-Path $imeWin32Path) {
    Write-Host "[+] Intune Management Extension (IME) Tracked Win32 Apps:" -ForegroundColor Yellow
    $appEntries = @()

    Get-ChildItem -Path $imeWin32Path -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -ne "Reporting" -and $_.PSChildName -ne "OperationalState" } | ForEach-Object {
        $userOrSystemSid = $_.PSChildName
        Get-ChildItem -Path $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if ($null -ne $props.ComplianceStateMessage) {
                try {
                    $json = $props.ComplianceStateMessage | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $installState = switch ($json.InstallState) {
                        1 { "Installed (1)" }
                        2 { "Not Installed (2)" }
                        3 { "Failed (3)" }
                        4 { "Install Pending (4)" }
                        default { $json.InstallState }
                    }
                    $appEntries += [PSCustomObject]@{
                        Context        = if ($userOrSystemSid -match "^00000000") { "System" } else { "User" }
                        AppId          = $_.PSChildName
                        InstallState   = $installState
                        ErrorCode      = $json.ErrorCode
                        TargetingMethod = $json.TargetingMethod
                    }
                } catch {}
            }
        }
    }

    if ($appEntries.Count -gt 0) {
        $appEntries | Format-Table -AutoSize
    } else {
        Write-Host "    No Win32 app compliance state messages recorded yet." -ForegroundColor Gray
    }
} else {
    Write-Host "[!] Intune Management Extension Win32Apps hive not yet present." -ForegroundColor Gray
}
