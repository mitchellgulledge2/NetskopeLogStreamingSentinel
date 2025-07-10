<#
.SYNOPSIS
Generates and uploads simulated log data to Azure Blob Storage.

.DESCRIPTION
This script creates 175,000 log events, structured similarly to the user-provided CSV sample.
It splits the data into multiple smaller files, compresses each into GZip format (.csv.gz),
and uploads them directly to the specified Azure Storage Blob container.

The script is designed to be run directly in Azure Cloud Shell.
#>

# --- 1. CONFIGURATION ---
$storageAccountName = "dtctest"
$containerName = "netskope"
$resourceGroupName  = "sa-mgulledge-log-analytics" # <-- This has been updated with your resource group.

# --- Data Generation Parameters ---
$totalEvents = 175000
$eventsPerFile = 10000 # The script will create multiple files for better performance.
$numberOfFiles = [Math]::Ceiling($totalEvents / $eventsPerFile)

# --- Script Start ---
Write-Host "🚀 Starting data generation and upload..."
Write-Host "-----------------------------------------------------"
Write-Host "Storage Account : $storageAccountName"
Write-Host "Container       : $containerName"
Write-Host "Resource Group  : $resourceGroupName"
Write-Host "Total Events    : $totalEvents (generating as rows)"
Write-Host "Files to Create : $numberOfFiles"
Write-Host "-----------------------------------------------------"

# Get the storage account context for the upload commands.
# This command assumes you are already logged into Azure in Cloud Shell.
try {
    $storageContext = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Context
    Write-Host "✅ Successfully connected to storage account." -ForegroundColor Green
}
catch {
    Write-Error "❌ Could not get storage account context. Please check the following:"
    Write-Error "   1. You are logged into the correct Azure directory/subscription in Cloud Shell."
    Write-Error "   2. The storage account name '$storageAccountName' is correct."
    Write-Error "   3. The resource group name '$resourceGroupName' is correct."
    return
}

# --- Data Generation Templates ---
$domains = @("salesforce.com", "dropbox.com", "gsuite.google.com", "microsoftonline.com", "github.com", "workday.com")
$activities = @("Login", "Logout", "Upload", "Download", "View", "Share")
$locations = @("USA", "GBR", "DEU", "IND", "AUS", "JPN")

# --- Main Generation and Upload Loop ---
for ($i = 1; $i -le $numberOfFiles; $i++) {
    $fileName = "simulated_log_$(Get-Date -Format 'yyyyMMddHHmmssfff')_part$i.csv"
    $gzFileName = "$($fileName).gz"
    
    Write-Host "`n($i/$numberOfFiles) Generating data for: $gzFileName"

    # Determine the number of events for this specific file.
    $eventsInThisFile = if (($i -eq $numberOfFiles) -and ($totalEvents % $eventsPerFile -ne 0)) { $totalEvents % $eventsPerFile } else { $eventsPerFile }

    # Use a generic list to hold the event objects for performance.
    $eventList = [System.Collections.Generic.List[PSObject]]::new()

    # Generate random data for each event in the current file.
    1..$eventsInThisFile | ForEach-Object {
        $eventTimestamp = ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - (Get-Random -Minimum 1 -Maximum 86400))
        $randomUser = "user" + (Get-Random -Minimum 100 -Maximum 999) + "@examplecorp.com"
        $randomSrcIp = "192.168.$(Get-Random -Minimum 1 -Maximum 254).$(Get-Random -Minimum 2 -Maximum 254)"
        $randomDstIp = "10.$(Get-Random -Minimum 0 -Maximum 254).$(Get-Random -Minimum 0 -Maximum 254).$(Get-Random -Minimum 2 -Maximum 254)"
        $randomDomain = $domains | Get-Random
        $randomActivity = $activities | Get-Random
        $bytesSent = Get-Random -Minimum 100 -Maximum 5000
        $bytesReceived = Get-Random -Minimum 1000 -Maximum 450000
        
        # Create a PowerShell object representing one row in the CSV.
        $event = [PSCustomObject]@{
            _time                   = (Get-Date).AddSeconds(- (Get-Random -Minimum 1 -Maximum 86400)).ToString("o")
            ccl                     = "private"
            admin_user_name         = ""
            timestamp               = $eventTimestamp
            user                    = $randomUser
            userkey                 = $randomUser
            organization_unit       = "Corporate Users"
            sourceip                = $randomSrcIp
            srchost                 = "workstation-" + (Get-Random -Minimum 100 -Maximum 999)
            src_location            = $locations | Get-Random
            destinationip           = $randomDstIp
            dsthost                 = $randomDomain
            dst_location            = $locations | Get-Random
            app                     = $randomDomain -replace '\..*$'
            app_category            = "Cloud Apps"
            page                    = "User Activity"
            csm_url_category        = "Business and Economy"
            traffic_type            = "CloudApp"
            from_user               = $randomUser
            to_user                 = ""
            activity                = $randomActivity
            access_method           = "Client"
            os                      = "Windows"
            os_version              = "11"
            browser                 = "Chrome"
            browser_version         = "126.0.0.0"
            device_classification   = "Managed"
            device_id               = ([System.Guid]::NewGuid()).Guid
            policy                  = "Allow Business Apps"
            rule_name               = "Default Outbound"
            alert_name              = ""
            alert_id                = ""
            severity                = ""
            alert_state             = ""
            dlp_profile             = ""
            dlp_file                = ""
            dlp_file_type           = ""
            dlp_file_size           = ""
            dlp_action              = ""
            dpa_status              = "allowed"
            forensic_status         = "NA"
            svcc                    = "private"
            bann                    = $randomDomain -replace '\..*$'
            urlo                    = "https://{0}/{1}" -f $randomDomain, $randomActivity
            url                     = "https://{0}/{1}" -f $randomDomain, $randomActivity
            urldomain               = $randomDomain
            urlquery                = ""
            urlfile                 = $randomActivity
            urlpath                 = "/$randomActivity"
            urlprotocol             = "https"
            urlext                  = ""
            urlhostname             = $randomDomain
            useragent               = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
            referer                 = "https://portal.example.com"
            contenttype             = "application/json"
            requestmethod           = "POST"
            bytestotal              = $bytesSent + $bytesReceived
            bytessent               = $bytesSent
            bytesreceived           = $bytesReceived
            clientip                = $randomSrcIp
            serverip                = $randomDstIp
        }
        $eventList.Add($event)
    }
    
    Write-Host "  -> Generated $eventsInThisFile events in memory."

    # Convert the list of objects to a single CSV string.
    $csvContent = $eventList | ConvertTo-Csv -NoTypeInformation | Out-String

    # Gzip the CSV content, all in memory.
    $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($csvContent)
    $memoryStream = [System.IO.MemoryStream]::new()
    $gzipStream = [System.IO.Compression.GZipStream]::new($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
    $gzipStream.Write($inputBytes, 0, $inputBytes.Length)
    $gzipStream.Close()
    $compressedBytes = $memoryStream.ToArray()
    $memoryStream.Close()

    # Create a new stream for the upload from the compressed byte array.
    $uploadStream = [System.IO.MemoryStream]::new($compressedBytes)
    $uploadStream.Position = 0

    Write-Host "  -> Compressing and uploading to Azure Blob Storage..."
    try {
        # Upload the in-memory stream directly to the blob.
        Set-AzStorageBlobContent -Context $storageContext -Container $containerName -Blob $gzFileName -ICloudBlobStream $uploadStream -Force
        $blobUri = "https://{0}.blob.core.windows.net/{1}/{2}" -f $storageAccountName, $containerName, $gzFileName
        Write-Host "  -> ✅ Upload successful: $blobUri" -ForegroundColor Green
    }
    catch {
        Write-Error "  -> ❌ Upload failed for $gzFileName. Error: $_"
    }
    finally {
        # Clean up the stream.
        $uploadStream.Close()
    }
}

Write-Host "`n🎉 Script finished. All files generated and uploaded."
