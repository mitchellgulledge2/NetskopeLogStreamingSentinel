# ==== CONFIGURATION ====
$storageAccountName = "<your-storage-account>"
$containerName = "<your-container-name>"
$resourceGroup = "<your-resource-group>"
$blobNames = @(
"file1.csv.gz",
"file2.csv.gz",
"file3.csv.gz"
)

# ==== LOGIN AND GET STORAGE CONTEXT ====
$storageAccountKey = (Get-AzStorageAccountKey -Name $storageAccountName -ResourceGroupName $resourceGroup)[0].Value
$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

# ==== FUNCTION TO COUNT LINES IN A GZIP FILE ====
function Get-GzipRowCount {
param (
[string]$blobName,
[Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageContext]$context,
[string]$container
)

$tempStream = New-Object System.IO.MemoryStream
Get-AzStorageBlobContent -Container $container -Blob $blobName -Context $context -Destination $tempStream -Force
$tempStream.Position = 0

$gzipStream = New-Object System.IO.Compression.GzipStream($tempStream, [IO.Compression.CompressionMode]::Decompress)
$reader = New-Object System.IO.StreamReader($gzipStream)

$rowCount = 0
while ($null -ne ($line = $reader.ReadLine())) {
$rowCount++
}

$reader.Close()
$gzipStream.Close()
$tempStream.Close()

return $rowCount
}

# ==== MAIN ====
$totalRows = 0

foreach ($blobName in $blobNames) {
try {
$count = Get-GzipRowCount -blobName $blobName -context $ctx -container $containerName
Write-Output "$blobName: $count rows"
$totalRows += $count
} catch {
Write-Warning "Failed to process $blobName: $_"
}
}

Write-Output "Total rows across all files: $totalRows"
