# Verifies that the Microsoft Entra provisioning agent services are installed
# and running on the local host. Run after installation and configuration.

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
