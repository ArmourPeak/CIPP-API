function Push-CIPPAlertVppTokenExpiry {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        $QueueItem,
        $TriggerMetadata
    )
    $LastRunTable = $QueueItem.LastRunTable

    try {
        $Filter = "RowKey eq 'VppTokenExpiry' and PartitionKey eq '{0}'" -f $QueueItem.tenantid
        $LastRun = Get-CIPPAzDataTableEntity @LastRunTable -Filter $Filter
        $Yesterday = (Get-Date).AddDays(-1)
        if (-not $LastRun.Timestamp.DateTime -or ($LastRun.Timestamp.DateTime -le $Yesterday)) {
            try {
                $VppTokens = (New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/deviceAppManagement/vppTokens' -tenantid $QueueItem.tenant).value
                foreach ($Vpp in $VppTokens) {
                    if ($Vpp.state -ne 'valid') {
                        Write-AlertMessage -tenant $($QueueItem.tenant) -message 'Apple Volume Purchase Program Token is not valid, new token required'
                    }
                    if ($Vpp.expirationDateTime -lt (Get-Date).AddDays(30) -and $Vpp.expirationDateTime -gt (Get-Date).AddDays(-7)) {
                        Write-AlertMessage -tenant $($QueueItem.tenant) -message ('Apple Volume Purchase Program token expiring on {0}' -f $Vpp.expirationDateTime)
                    }
                }
            } catch {}
            $LastRun = @{
                RowKey       = 'VppTokenExpiry'
                PartitionKey = $QueueItem.tenantid
            }
            Add-CIPPAzDataTableEntity @LastRunTable -Entity $LastRun -Force
        }
    } catch {
        # Error handling
    }
}