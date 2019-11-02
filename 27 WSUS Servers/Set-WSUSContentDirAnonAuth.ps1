$Remediate = $false
Import-Module WebAdministration
$UseAppPoolIdentity = (Get-WebConfigurationProperty -Filter 'system.WebServer/security/authentication/AnonymousAuthentication' -Name username -Location 'WSUS Administration/Content') -eq ''
switch ($UseAppPoolIdentity) {
    $true {
        $true
    }
    $false {
        switch ($Remediate) {
            $true {
                Set-WebConfigurationProperty -Filter 'system.WebServer/security/authentication/AnonymousAuthentication' -name username -value '' -location 'WSUS Administration/Content'
                $true
            }
            $false {
                $false
            }
        }
    }
}
