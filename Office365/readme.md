End Product - One application with 17 deployment types that will dynamically install the 'new' version of Office / Project / Visio as needed. 
<a href="https://imgur.com/IyY6hGS"><img src="https://i.imgur.com/IyY6hGS.png" title="source: imgur.com" /></a>  

You can place all the XML, and Office 365 c2r setup.exe in a directory. 

You'll want to run:

setup.exe /download Office365.xml

Once to get the ball rolling. The binaries are the same for every single app combination. 

The script has 5 parameters that you can see below. 

$new365DynamicAppSplat = @{  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ApplicationName = 'Office 365 with Visio/Project Pro/Standard 2016/2019 x86';  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SMSProvider = 'SCCM.CONTOSO.COM';  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Company = 'Contoso';  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;AppRoot = '\\\Contoso.com\apps\Office365Magic';  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Bitness = 'x86';  
}  
New-365DynamicApp @new365DynamicAppSplat 

This will use the info and XML to generate an application with 17 deployment types for you. It is every combination of O365, Visio/Project Professional/Standard 2016/2019.
