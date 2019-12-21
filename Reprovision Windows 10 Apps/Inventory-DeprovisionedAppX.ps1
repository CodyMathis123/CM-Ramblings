#region define your Hardware Inventory Class Name, and the namespace in WMI to store it
$HinvClassName = 'DeprovisionedAppX'
$HinvNamespace = 'root\CustomHinv'
#endregion define your Hardware Inventory Class Name, and the namespace in WMI to store it

#region test if the namespace exists, and create it if it does not
try {
    $null = [wmiclass]"$HinvNamespace`:__NameSpace"
}
catch {
    $HinvNamespaceSplit = $HinvNamespace -split '\\'
    $PathToTest = $HinvNamespaceSplit[0]
    for (${i} = 1; ${i} -lt $($HinvNamespaceSplit.Count); ${i}++) {
        $PathToTest = [string]::Join('\', @($PathToTest, $HinvNamespaceSplit[$i]))
        try {
            $null = [wmiclass]"$PathToTest`:__NameSpace"
        }
        catch {
            $PathToTestParent = Split-Path -Path $PathToTest -Parent
            $PathToTestName = Split-Path -Path $PathToTest -Leaf
            $NewNamespace = [wmiclass]"$PathToTestParent`:__NameSpace"
            $NamespaceCreation = $NewNamespace.CreateInstance()
            $NamespaceCreation.Name = $PathToTestName
            $null = $NamespaceCreation.Put()
        }
    }
}
#endregion test if the namespace exists, and create it if it does not

#region clear our class from the namespace if it exists
Remove-WmiObject -Class $HinvClassName -Namespace $HinvNamespace -ErrorAction SilentlyContinue
#endregion clear our class from the namespace if it exists

#region create the WMI class, and set the properties to be inventoried
$HinvClass = [System.Management.ManagementClass]::new($HinvNamespace, [string]::Empty, $null)
$HinvClass["__CLASS"] = $HinvClassName
$HinvClass.Qualifiers.Add("Static", $true)
$HinvClass.Properties.Add("DeprovisionedApp", [System.Management.CimType]::String, $false)
$HinvClass.Properties["DeprovisionedApp"].Qualifiers.Add("Key", $true)
$null = $HinvClass.Put()
#endregion create the WMI class, and set the properties to be inventoried

$DeprovisionRoot = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned"
$AllDeprovisionedApps = Get-ChildItem -Path $DeprovisionRoot | Select-Object -ExpandProperty PSChildName
if ($null -ne $AllDeprovisionedApps) {
    foreach ($App in $AllDeprovisionedApps) {
        $null = Set-WmiInstance -Namespace $HinvNamespace -Class $HinvClassName -ErrorAction SilentlyContinue -Arguments @{
            DeprovisionedApp = $App
        }
    }
}

Write-Output 'Inventory Complete'