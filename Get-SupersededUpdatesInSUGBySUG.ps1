$SUG = Get-CMSoftwareUpdateGroup -Name 'Sug Name'
$allInSUG = Get-CMSoftwareUpdate -UpdateGroup $SUG
$updatesSugSupersedes = foreach ($Updates in $allInSUG) {
    ([xml]$Updates.sdmpackagexml).DesiredConfigurationDigest.SoftwareUpdate.SupersededUpdates.SoftwareUpdateReference.LogicalName
}
$supersededUpdatesToRemove = $allInSUG.Where( { [string]::Format("SUM_{0}", $_.CI_UniqueID) -in $updatesSugSupersedes })
$supersededUpdatesToRemove.LocalizedDisplayName
