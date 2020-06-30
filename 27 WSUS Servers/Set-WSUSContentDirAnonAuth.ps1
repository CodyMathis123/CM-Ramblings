$Remediate = $false

Import-Module WebAdministration
$UseAppPoolIdentity = (Get-WebConfiguration "/system.applicationHost/sites/site[@name='WSUS Administration']/application[@path='/']/virtualdirectory[@path='/Content']").userName -eq [string]::Empty
switch ($UseAppPoolIdentity) {
    $true {
        $true
    }
    $false {
        switch ($Remediate) {
            $true {
                Set-WebConfiguration "/system.applicationHost/sites/site[@name='WSUS Administration']/application[@path='/']/virtualdirectory[@path='/Content']" -Value @{userName = ''; password = '' }
                $true
            }
            $false {
                $false
            }
        }
    }
}