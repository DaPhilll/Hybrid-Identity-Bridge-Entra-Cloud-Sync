# Verifies that the Microsoft Entra provisioning agent services are installed
# and running on the local host. Run after installation and configuration.
#
# Service naming note: Get-Service -Name matches the service short name, not the
# display name. The provisioning agent's short name is AADConnectProvisioningAgent
# and has stayed stable across Microsoft's Azure AD to Entra rebrand, while the
# display name changed from "Microsoft Azure AD Connect Provisioning Agent" to
# "Microsoft Entra Connect Provisioning Agent". Display-name lookups below use
# wildcards so they match either branding.

$allHealthy = $true

function Test-AgentService {
    param(
        [string]$Label,
        [string]$ShortName,
        [string]$DisplayPattern
    )

    $service = $null
    if ($ShortName) {
        $service = Get-Service -Name $ShortName -ErrorAction SilentlyContinue
    }
    if ($null -eq $service -and $DisplayPattern) {
        $service = Get-Service -DisplayName $DisplayPattern -ErrorAction SilentlyContinue |
                   Select-Object -First 1
    }

    if ($null -eq $service) {
        Write-Host "MISSING | $Label is not installed on this host."
        return $false
    }

    if ($service.Status -eq "Running") {
        Write-Host "OK      | $Label is running (service: $($service.Name))."
        return $true
    }

    Write-Host "STOPPED | $Label is installed but not running (status: $($service.Status))."
    return $false
}

if (-not (Test-AgentService -Label "Provisioning Agent" `
        -ShortName "AADConnectProvisioningAgent" `
        -DisplayPattern "*Connect Provisioning Agent*")) {
    $allHealthy = $false
}

if (-not (Test-AgentService -Label "Agent Updater" `
        -ShortName $null `
        -DisplayPattern "*Connect Agent Updater*")) {
    $allHealthy = $false
}

# Microsoft's documentation lists the install directory under both names,
# so check each rather than assuming one.
$candidatePaths = @(
    "C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\AADConnectProvisioningAgent.exe",
    "C:\Program Files\Azure AD Connect Provisioning Agent\AADConnectProvisioningAgent.exe"
)

$agentPath = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($agentPath) {
    $version = (Get-Item $agentPath).VersionInfo.ProductVersion
    Write-Host "Agent version: $version"
} else {
    Write-Host "MISSING | Agent executable not found in any expected install directory."
    $allHealthy = $false
}

if ($allHealthy) {
    Write-Host "`nResult: Provisioning agent appears healthy on this host."
} else {
    Write-Host "`nResult: One or more checks failed. Confirm agent status in the Entra admin center under Entra Connect > Cloud Sync > Agents before troubleshooting further."
}
