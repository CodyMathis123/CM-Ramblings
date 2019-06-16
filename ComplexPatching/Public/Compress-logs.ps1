param
(
    [parameter(Mandatory = $true)]
    [int32]$RBInstance,
    # Provides the RB instance for the purposes of finding logs and naming the zip

    [parameter(Mandatory = $true)]
    [string]$Grouping,
    # Provides the grouping of the servers we are compresses logs for

    [parameter(Mandatory = $true)]
    [string]$LogLocation
    # UNC path to store log files in
)

#region functions
function ZipFiles {
    param (
        [string]$ZipFileName,
        # the file name for the zip file, should include .zip
        [string]$SourceDir
        # the source directory to zip up
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDir, $ZipFileName, $compressionLevel, $false)
}
#endregion functions

$Destination = New-Item -Path $LogLocation -ItemType Directory -Name "$RBInstance-$Grouping"
$LogFilter = [string]::Format("{0}-*.log", $RBInstance)
Get-ChildItem -Path $LogLocation -Filter $LogFilter | Move-Item -Destination $Destination
ZipFiles -ZipFileName (Join-Path $LogLocation -ChildPath "$RBInstance-$Grouping.zip") -SourceDir $Destination
Remove-Item $Destination -Force:$true -Confirm:$false -Recurse:$true