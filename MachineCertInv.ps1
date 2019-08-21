## Define new class name and date
$NewClassName = 'Win32_MachineCerts'

## Remove class if exists
Remove-WmiObject -Class $NewClassName -ErrorAction SilentlyContinue

# Create new WMI class
$newClass = New-Object System.Management.ManagementClass ("root\cimv2", [String]::Empty, $null)
$newClass["__CLASS"] = $NewClassName

## Create properties you want inventoried
$newClass.Qualifiers.Add("Static", $true)
$newClass.Properties.Add("PSPath", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("PSParentPath", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("Issuer", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("Subject", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("FriendlyName", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("Version", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("Thumbprint", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("NotAfter", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("NotBefore", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("DNSNameList", [System.Management.CimType]::String, $false)
$newClass.Properties["PSPath"].Qualifiers.Add("Key", $true)
$newClass.Put() | Out-Null

## Gather current cert information
Get-ChildItem Cert:\LocalMachine -Recurse | Where-Object { $_.PSisContainer -eq $false } | Select-Object PSPath, PSparentpath, Issuer, Subject, FriendlyName, Version, Thumbprint, NotAfter, NotBefore, DNSNamelist | 
ForEach-Object {

    ## Set cert information in new class
    Set-WmiInstance -Namespace root\cimv2 -class $NewClassName -ErrorAction SilentlyContinue -Arguments @{
        PSParentPath = $_.PSParentPath
        Issuer       = $_.Issuer
        Subject      = $_.Subject
        FriendlyName = $_.FriendlyName
        Version      = $_.Version
        Thumbprint   = $_.Thumbprint
        NotAfter     = $_.NotAfter
        NotBefore    = $_.NotBefore
        DNSNamelist  = $_.DNSNamelist
        PSPath       = $_.PSPath
    } | Out-Null
}

Write-Output "Complete"
