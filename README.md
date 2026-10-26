# Windows Autopilot Diagnostics & Readiness Toolkit 🚀

[![Website](https://img.shields.io/badge/Companion%20Guides-adminsignal.com-0078D4?style=for-the-badge&logo=google-chrome&logoColor=white)](https://adminsignal.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207+-blue?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/AdminSignalHQ/autopilot-diagnostics-toolkit)

A field-tested PowerShell toolkit for validating **Windows Autopilot** readiness before retiring ConfigMgr task sequence OSD, inspecting **Enrollment Status Page (ESP)** failures live during OOBE (Shift + F10), and bundling MDM/IME diagnostic logs.

Companion repository to the Autopilot migration guides on [**adminsignal.com**](https://adminsignal.com).

---

## 🛠️ Included Tools

| Script | Purpose | When to Use |
| :--- | :--- | :--- |
| [**Test-AutopilotReadiness.ps1**](Test-AutopilotReadiness.ps1) | Pre-flight hardware, TPM 2.0, WMI hash, time sync, and TLS endpoint reachability check. | Run before wiping legacy devices or during pilot ring validation. |
| [**Get-AutopilotESPStatus.ps1**](Get-AutopilotESPStatus.ps1) | Parses local Autopilot profile cache, ESP phase states, and IME Win32 app installation states. | Run during OOBE (Shift + F10) when ESP hangs on *Device Setup* or *Account Setup*. |
| [**Export-AutopilotDiagnosticBundle.ps1**](Export-AutopilotDiagnosticBundle.ps1) | Automates MdmDiagnosticsTool, collects IME logs, exports Event Viewer .evtx files, and zips them into one bundle. | Run on failed provisioning devices to capture a single .zip for root-cause analysis. |

---

## ⚡ Quick Usage Examples

### 1. Pre-Flight Readiness Check
Verify that a device meets all hardware, TPM attestation, and firewall requirements for Windows Autopilot:
`powershell
.\Test-AutopilotReadiness.ps1
`

### 2. Live ESP & Win32 App Status Triage (During OOBE)
Press Shift + F10 at the Enrollment Status Page, launch powershell, and run:
`powershell
.\Get-AutopilotESPStatus.ps1
`

### 3. Collect Full Autopilot & IME Log Archive
`powershell
.\Export-AutopilotDiagnosticBundle.ps1 -OutputDirectory "C:\Temp"
`

---

## 📖 Related Guides on AdminSignal
* [Retiring ConfigMgr Task Sequence OSD for Windows Autopilot](https://adminsignal.com)
* [Troubleshooting Enrollment Status Page (ESP) Timeouts and Win32 App Failures](https://adminsignal.com)
