You can place all the XML, and Office 365 c2r setup.exe in a directory. 

You'll want to run:

setup.exe /download Office365.xml

Once to get the ball rolling. The binaries are the same for every single app combination. 

The script has 4 parameters that you can see below. 

$new365DynamicAppSplat = @{
    ApplicationName = 'Office 365 with Visio/Project Pro/Standard 2016/2019 x86' 
    SMSProvider = 'SCCM.CONTOSO.COM'
    Company = 'Contoso'
    AppRoot = "\\Contoso.com\apps\Office365Magic"
}
New-365DynamicApp @new365DynamicAppSplat 

This will use the info and XML to generate an application with 17 deployment types for you. 
