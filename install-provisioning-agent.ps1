# Silent installation of the Microsoft Entra provisioning agent for Cloud Sync.
# Run on the host server (SRV-DC01 or a dedicated tier 0 member server).
#
# Prerequisites (verify before running):
#   - Windows Server 2016 or later, domain-joined, minimum 4 GB RAM
#   - TLS 1.2 enabled
#   - PowerShell execution policy set to Undefined or RemoteSigned
#   - .NET 4.7.1 or later
#   - Signed in account has at least the Hybrid Identity Administrator role in Entra ID
#
# The installer package must be downloaded manually from the Entra admin center
# (Entra ID > Entra Connect > Cloud Sync > Agents > Download on-premises agent),
# since the download requires an authenticated portal session.

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
