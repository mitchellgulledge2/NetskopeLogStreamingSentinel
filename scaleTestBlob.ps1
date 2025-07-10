<#
.SYNOPSIS
Generates and uploads simulated log data to Azure Blob Storage.

.DESCRIPTION
This definitive version first sets the Azure subscription context to ensure all commands
run in the correct environment. It then fetches the storage account key to create a
reliable authentication context, generates 175,000 log events, compresses them,
and uploads them to the specified blob container.
#>

# --- 1. CONFIGURATION ---
$subscriptionId     = "xxx"
$storageAccountName = "xxx"
$containerName      = "xxx"
$resourceGroupName  = "xxx"

# --- 2. SCRIPT PARAMETERS ---
$totalEvents = 175000
$eventsPerFile = 10000
$numberOfFiles = [Math]::Ceiling($totalEvents / $eventsPerFile)

# --- 3. SCRIPT EXECUTION ---
Write-Host "🚀 Starting data generation and upload..."
Write-Host "-----------------------------------------------------"
Write-Host "Subscription    : $subscriptionId"
Write-Host "Storage Account : $storageAccountName"
Write-Host "Resource Group  : $resourceGroupName"
Write-Host "-----------------------------------------------------"

# --- Step 1: Set the Azure Subscription Context ---
Write-Host "🔐 Setting active subscription context..."
try {
    Set-AzContext -Subscription $subscriptionId | Out-Null
    Write-Host "✅ Subscription context set to '$subscriptionId'" -ForegroundColor Green
}
catch {
    Write-Error "❌ CRITICAL ERROR: Could not set the subscription context."
    Write-Error "Please verify that the subscription ID '$subscriptionId' is correct and that your account has access to it."
    return # Stop the script
}

# --- Step 2: Explicitly Get Storage Account Key and Create Context ---
Write-Host "🔑 Fetching storage account key to create a secure context..."
try {
    $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    Write-Host "✅ Successfully created storage context." -ForegroundColor Green
}
catch {
    Write-Error "❌ CRITICAL ERROR: Could not get the storage account key or create a context."
    Write-Error "This usually means a permissions issue. Please ensure your user has the 'Storage Blob Data Contributor' or 'Contributor' role on the '$storageAccountName' storage account."
    return # Stop the script
}

# --- Data Generation Templates ---
$domains = @("salesforce.com", "dropbox.com", "gsuite.google.com", "microsoftonline.com", "github.com", "workday.com")
$activities = @("Login", "Logout", "Upload", "Download", "View", "Share")
$locations = @("USA", "GBR", "DEU", "IND", "AUS", "JPN")

# --- Main Generation and Upload Loop ---
for ($i = 1; $i -le $numberOfFiles; $i++) {
    $localTempGzPath = Join-Path -Path $HOME -ChildPath "temp_simulated_log_part$i.csv.gz"
    $blobName = "simulated_log_$(Get-Date -Format 'yyyyMMddHHmmssfff')_part$i.csv.gz"
    
    Write-Host "`n($i/$numberOfFiles) Generating data for: $blobName"

    $eventsInThisFile = if (($i -eq $numberOfFiles) -and ($totalEvents % $eventsPerFile -ne 0)) { $totalEvents % $eventsPerFile } else { $eventsPerFile }
    $eventList = [System.Collections.Generic.List[PSObject]]::new()

    1..$eventsInThisFile | ForEach-Object {
        $randomUser = "user" + (Get-Random -Minimum 100 -Maximum 999) + "@examplecorp.com"
        $event = [PSCustomObject]@{
            _time                   = (Get-Date).AddSeconds(- (Get-Random -Minimum 1 -Maximum 86400)).ToString("o")
            timestamp               = ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - (Get-Random -Minimum 1 -Maximum 86400))
            user                    = $randomUser
            sourceip                = "192.168.$(Get-Random -Minimum 1 -Maximum 254).$(Get-Random -Minimum 2 -Maximum 254)"
            dsthost                 = ($domains | Get-Random)
            activity                = ($activities | Get-Random)
            # Add other fields as needed based on the sample file
        }
        $eventList.Add($event)
    }
    
    $csvContent = $eventList | ConvertTo-Csv -NoTypeInformation
    $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)
    $fileStream = [System.IO.FileStream]::new($localTempGzPath, [System.IO.FileMode]::Create)
    $gzipStream = [System.IO.Compression.GZipStream]::new($fileStream, [System.IO.Compression.CompressionMode]::Compress)
    $gzipStream.Write($inputBytes, 0, $inputBytes.Length)
    $gzipStream.Close(); $fileStream.Close()

    Write-Host "  -> Uploading to Azure..."
    try {
        Set-AzStorageBlobContent -Context $storageContext -Container $containerName -File $localTempGzPath -Blob $blobName -Force
        $blobUri = "https://{0}.blob.core.windows.net/{1}/{2}" -f $storageAccountName, $containerName, $blobName
        Write-Host "  -> ✅ Upload successful: $blobUri" -ForegroundColor Green
    }
    catch {
        Write-Error "  -> ❌ Upload failed for $blobName. Error: $_"
    }
    finally {
        if (Test-Path $localTempGzPath) {
            Remove-Item $localTempGzPath
        }
    }
}

Write-Host "`n🎉 Script finished. All files generated and uploaded."
