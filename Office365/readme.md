End Product - One application with all possible deployment types that will dynamically install the 'new' version of Office / Project / Visio as needed based on your licensing selection. 


<a href="https://imgur.com/0Cq1SQd"><img src="https://i.imgur.com/0Cq1SQd.png?1" title="source: imgur.com" /></a>
<a href="https://imgur.com/uSCBK6n"><img src="https://i.imgur.com/uSCBK6n.png?1" title="source: imgur.com" /></a>
<a href="https://imgur.com/5wa7VN9"><img src="https://i.imgur.com/5wa7VN9.png?1" title="source: imgur.com" /></a>
<a href="https://imgur.com/0SSlGi6"><img src="https://i.imgur.com/0SSlGi6.png?1" title="source: imgur.com" /></a>

You can place all the XML, and Office 365 c2r setup.exe in a directory. 

You'll want to run:

setup.exe /download Office365.xml

Once to get the ball rolling. The binaries are the same for every single app combination. 

The script has 11 parameters that you can see below in the help info from the script.

.PARAMETER SMSProvider<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the name for the SMSProvider for the environment you want to create the application in.<br>
.PARAMETER ApplicationName<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the name which you want assigned to the application that is created by this script.<br>
.PARAMETER Company<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the company name you want specified in all of the XML files.<br>
.PARAMETER AppRoot<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the root directory for the application to be created. This should be pre-populated with the provided XML files,<br>
&nbsp;&nbsp;&nbsp;&nbsp;and it will be used as the source directory for all the deployment types.<br>
.PARAMETER Bitness<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the desired architecture for the deployment types. All of the XML will be updated with this value.<br>
&nbsp;&nbsp;&nbsp;&nbsp;'x86', 'x64'<br>
.PARAMETER VisioLicense<br>
&nbsp;&nbsp;&nbsp;&nbsp;Allows you to select the license type which you are licensed for. This will be either 'Online' or 'Volume'<br>
&nbsp;&nbsp;&nbsp;&nbsp;Note that if 'Volume' is selected, you will see that Visio 2016 as well as 2019 deployment types are created, and have requirements<br>
&nbsp;&nbsp;&nbsp;&nbsp;for Windows 7 or 8/8.1 attached to them. Visio 2019 deployment types are targeted at Windows 10.<br>
.PARAMETER ProjectLicense<br>
&nbsp;&nbsp;&nbsp;&nbsp;Allows you to select the license type which you are licensed for. This will be either 'Online' or 'Volume'<br>
&nbsp;&nbsp;&nbsp;&nbsp;Note that if 'Volume' is selected, you will see that Project 2016 as well as 2019 deployment types are created, and have requirements<br>
&nbsp;&nbsp;&nbsp;&nbsp;for Windows 7 or 8/8.1 attached to them. Project 2019 deployment types are targeted at Windows 10.<br>
.PARAMETER UpdateChannel<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the desired Update Channel for the deployment types. All of the XML will be updated with this value.<br>
&nbsp;&nbsp;&nbsp;&nbsp;'Semi-Annual', 'Semi-AnnualTargeted', 'Monthly', 'MonthlyTargeted'<br>
.PARAMETER Version<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the desired Version for the Office 365 installation. All of the XML will be updated with this value.<br>
&nbsp;&nbsp;&nbsp;&nbsp;By default, we attempt to gather the latest deployed patch version based on the Update Channel selected.<br>
.PARAMETER AllowCdnFallback<br>
&nbsp;&nbsp;&nbsp;&nbsp;A boolean value that will be set in the XML files. This will allow your clients to fallback to the Content Delivery Network (CDN)<br>
&nbsp;&nbsp;&nbsp;&nbsp;aka 'the cloud.'<br>
.PARAMETER DisplayLevel<br>
&nbsp;&nbsp;&nbsp;&nbsp;Provides the desired display level for the Office 365 installer. This can be either 'Full' or 'None. All of the XML will be updated with this value. <br>

$appName = 'Office 365 - Visio Volume and Project Volume'<br>
$New365DynamicAppSplat = @{<br>
&nbsp;&nbsp;&nbsp;&nbsp;AppRoot = '\\contoso.com\DFS\CM\Applications\Office365\O365-DynamicInstall'<br>
&nbsp;&nbsp;&nbsp;&nbsp;ProjectLicense = 'Volume'<br>
&nbsp;&nbsp;&nbsp;&nbsp;ApplicationName = $AppName<br>
&nbsp;&nbsp;&nbsp;&nbsp;SMSProvider = 'SCCM'<br>
&nbsp;&nbsp;&nbsp;&nbsp;VisioLicense = 'Volume'<br>
&nbsp;&nbsp;&nbsp;&nbsp;Company = 'Contoso'<br>
&nbsp;&nbsp;&nbsp;&nbsp;Bitness = 'x64'<br>
&nbsp;&nbsp;&nbsp;&nbsp;UpdateChannel = 'Semi-Annual'<br>
}<br>
.\New-365DynamicApp.ps1 @New365DynamicAppSplat<br>

This will use the info and XML to generate an application with 17 deployment types for you. It is every combination of O365, Visio/Project Professional/Standard 2016/2019 volume licensed. 
