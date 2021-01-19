param(
    $SoftwareUpdateGroupName
)
# return a list of updates which are superseded by another update in the same SUG
$SUG = Get-CMSoftwareUpdateGroup -Name $SoftwareUpdateGroupName
$allInSUG = Get-CMSoftwareUpdate -UpdateGroup $SUG
$updatesSugSupersedes = foreach ($Updates in $allInSUG) {
    ([xml]$Updates.sdmpackagexml).GetElementsByTagName("SupersededUpdates").SoftwareUpdateReference.LogicalName
}
return $allInSUG.Where( { [string]::Format("SUM_{0}", $_.CI_UniqueID) -in $updatesSugSupersedes })
