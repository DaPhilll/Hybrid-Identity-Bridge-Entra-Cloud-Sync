[![Darreon Phillips Homepage](https://img.shields.io/badge/Darreon%20Phillips-Homepage-blue?style=for-the-badge&logo=github&logoColor=white)](https://github.com/DaPhilll)

# Hybrid Identity Bridge: Entra Cloud Sync and Risk-Based Access Control

## Repository Structure
```
/scripts
  install-provisioning-agent.ps1
  verify-agent-health.ps1
/policies
  require-mfa-admin-roles.json
  block-legacy-authentication.json
  signin-risk-require-mfa-report-only.json
  user-risk-require-password-change-report-only.json
LICENSE
README.md
```

## 1. Executive Summary & Objective
* **Problem Statement:** Cloud identity platforms need a reliable bridge to on-premises Active Directory, and that bridge needs risk-aware access controls behind it. Without hybrid sync, cloud security tooling has no visibility into on-premises accounts. Without Conditional Access and risk-based policies layered on top, a synced identity is only as protected as its password.
* **Solution Overview:** This project connected the on-premises domain controller (`SRV-DC01`) to a Microsoft Entra ID tenant using Entra Cloud Sync, then applied a set of Conditional Access policies covering admin role protection, legacy authentication, and Identity Protection risk signals. The sync and all four policies have been deployed and verified.
* **Core Capabilities:**
  * Lightweight, agent-based synchronization from on-premises AD to Entra ID.
  * Conditional Access enforcement for privileged directory roles.
  * Legacy authentication protocol blocking.
  * Risk-based Conditional Access policies for sign-in risk and user risk, deployed in report-only mode.

## 2. Architecture & Environment Topology
This project extends the shared lab environment (VMware Workstation Pro, `10.10.0.0/24`) into a Microsoft Entra ID tenant, rather than standing up a separate isolated cloud environment.

* **On-Premises Domain Controller:** `SRV-DC01`, hosting the Microsoft Entra provisioning agent.
* **Sync Method:** Microsoft Entra Cloud Sync, chosen over Entra Connect Sync for its lighter footprint and Microsoft's current recommended default for new hybrid deployments.
* **Cloud Tenant:** Microsoft Entra ID (Microsoft 365 Developer Program tenant).
* **Licensing Dependency:** The risk-based Conditional Access policies require Microsoft Entra ID P2, which is included in Microsoft 365 E5 Developer Program tenants.

## 3. Engineering Thought Process & Methodology
* **Design Considerations:** Entra Connect Sync requires a dedicated sync server and a SQL Server-backed configuration database. Entra Cloud Sync removes both requirements, running as a lightweight agent that can be installed directly on a domain controller. For a single-domain lab environment with no complex multi-forest requirements, Cloud Sync's reduced operational overhead outweighs the additional customization Entra Connect Sync offers.
* **Technical Challenges & Resolution:**
  * **Challenge:** Microsoft is retiring the legacy standalone Identity Protection risk policy configuration on October 1, 2026, in favor of risk-based conditions inside Conditional Access itself.
  * **Resolution:** The risk policies in this repository are built directly as Conditional Access policies using the `userRiskLevels` and `signInRiskLevels` condition fields, rather than the legacy configuration path, so they don't need to be migrated later.

## 4. Cyber Kill Chain & Threat Lifecycle Mapping
* **Initial Access:** Blocking legacy authentication protocols removes a common credential-stuffing path that bypasses modern authentication and Conditional Access entirely.
* **Credential Access & Privilege Escalation:** Requiring MFA on privileged directory roles limits the impact of a single compromised admin credential.
* **Post-Compromise Detection:** Sign-in risk and user risk policies give an automated response path when Identity Protection detects signals like leaked credentials or atypical travel, rather than relying solely on manual review.

## 5. Compliance Alignment

| Control Area | NIST SP 800-53 | SOC 2 TSC |
| :--- | :--- | :--- |
| MFA for Privileged Roles | IA-2, AC-6 | CC6.1 |
| Legacy Authentication Blocking | AC-17, SC-7 | CC6.6 |
| Risk-Based Access Control | AC-2, SI-4 | CC6.1, CC7.2 |

This extends the same NIST SP 800-53 and SOC 2 Type II mapping used in the GRC and Linux Hardening repositories to the identity layer.

## 6. Reference Documentation
* Microsoft Entra Cloud Sync installation and prerequisites (Microsoft Learn).
* Microsoft Entra ID Protection risk-based Conditional Access policy guidance (Microsoft Learn), including the October 1, 2026 retirement of legacy risk policies.
* Role template IDs and object IDs in the policy files below are shown as placeholders. Real values were used for the actual tenant configuration, but tenant-specific identifiers are redacted here as standard practice for a public repository, not because they were left unresolved.

## 7. Implementation & Code

### Provisioning Agent Installation
`scripts/install-provisioning-agent.ps1` — installs the Microsoft Entra provisioning agent in quiet mode from a pre-downloaded installer package. The installer itself must be downloaded manually from the Entra admin center, since that download requires an authenticated portal session.
```powershell
param(
    [string]$InstallerPath = "C:\Temp\AADConnectProvisioningAgentSetup.exe"
)

if (-not (Test-Path $InstallerPath)) {
    Write-Error "Installer not found at $InstallerPath. Download it from the Entra admin center first."
    exit 1
}

Write-Host "Installing Microsoft Entra provisioning agent in quiet mode..."
$installerProcess = Start-Process $InstallerPath -ArgumentList "/quiet" -NoNewWindow -PassThru
$installerProcess.WaitForExit()

if ($installerProcess.ExitCode -eq 0) {
    Write-Host "Installer completed. Launch the configuration wizard manually to sign in with a Hybrid Identity Administrator account and complete setup."
} else {
    Write-Error "Installer exited with code $($installerProcess.ExitCode)."
}
```

### Agent Health Verification
`scripts/verify-agent-health.ps1` — checks that both provisioning agent services are installed and running, and confirms the agent version.
```powershell
$services = @(
    "Microsoft Azure AD Connect Agent Updater",
    "Microsoft Azure AD Connect Provisioning Agent"
)

$allHealthy = $true

foreach ($serviceName in $services) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Host "MISSING | $serviceName is not installed on this host."
        $allHealthy = $false
        continue
    }

    if ($service.Status -eq "Running") {
        Write-Host "OK      | $serviceName is running."
    } else {
        Write-Host "STOPPED | $serviceName is installed but not running (status: $($service.Status))."
        $allHealthy = $false
    }
}

$agentPath = "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\AADConnectProvisioningAgent.exe"
if (Test-Path $agentPath) {
    $version = (Get-Item $agentPath).VersionInfo.ProductVersion
    Write-Host "Agent version: $version"
} else {
    Write-Host "MISSING | Agent executable not found at expected path: $agentPath"
    $allHealthy = $false
}

if ($allHealthy) {
    Write-Host "`nResult: Provisioning agent appears healthy on this host."
} else {
    Write-Host "`nResult: One or more checks failed. Confirm agent status in the Entra admin center under Entra Connect > Cloud Sync > Agents before troubleshooting further."
}
```

### Cloud Sync Configuration (Portal Steps)
The scoping and attribute mapping configuration for Cloud Sync was done through the Entra admin center, not through a script, since it has no supported CLI-only path for scoping filters. Steps followed, once the agent was installed and confirmed active under Entra Connect > Cloud Sync > Agents:
1. Entra admin center > Entra ID > Entra Connect > Cloud Sync > New configuration > AD to Microsoft Entra ID sync.
2. Selected the on-premises domain and enabled password hash sync.
3. Configured scoping filters to limit the initial sync to a pilot organizational unit rather than the full directory.
4. Reviewed default attribute mappings; no changes were needed for this environment.
5. Saved and started provisioning. Sync runs on a 2-minute schedule.

`scripts/verify-agent-health.ps1` was run after configuration and confirmed both services running and the agent registered as active in the Entra admin center.

## 8. Conditional Access Policies
All four policies below were created in the tenant and confirmed active under Entra ID > Conditional Access.

### Require MFA for Admin Roles
`policies/require-mfa-admin-roles.json` — requires MFA for any sign-in using a Global Administrator or Privileged Role Administrator role, with a 4-hour sign-in frequency limit. Deployed and enabled.

### Block Legacy Authentication
`policies/block-legacy-authentication.json` — blocks sign-ins from clients that don't support modern authentication (older IMAP, POP, SMTP AUTH clients). Deployed and enabled.

### Sign-In Risk: Require MFA (Report-Only)
`policies/signin-risk-require-mfa-report-only.json` — applies to High and Medium sign-in risk levels, requiring MFA. Deployed in report-only mode, per Microsoft's own recommended first step, to confirm impact before enforcing.

### User Risk: Require Password Change (Report-Only)
`policies/user-risk-require-password-change-report-only.json` — applies to High user risk, requiring a password change. Password writeback was enabled for hybrid users synced from `SRV-DC01` to support this remediation path.

## 9. Hardening & Future Enhancements
* **Current Posture:** The sync agent is confirmed healthy and active. Both admin-role and legacy-authentication policies are deployed and enforced. The two risk-based policies remain in report-only mode by design, matching Microsoft's own recommended posture before moving to enforcement, not an incomplete step.
* **Future Roadmap:**
  * [ ] Move the two report-only risk policies to enforced after a review period, once sign-in log data confirms no false positives against legitimate lab traffic.
  * [ ] Forward Entra ID sign-in logs to the Sentinel workspace referenced in the Detection-as-Code repository for cross-platform correlation with on-premises telemetry.

## License
MIT — see [LICENSE](./LICENSE).

<br><br><br>
[![Darreon Phillips Homepage](https://img.shields.io/badge/Darreon%20Phillips-Homepage-blue?style=for-the-badge&logo=github&logoColor=white)](https://github.com/DaPhilll)
