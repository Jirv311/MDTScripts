<#	
	.NOTES
	===========================================================================
	 Created on:   	07/01/2024
	 Created by:   	Jeff Irvine
	 Organization: 	Techmological
	 Filename:     	CustomizeWindowsOffline.ps1
	===========================================================================
	.DESCRIPTION
		Customizes Windows 11 from MDT.
#>
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$OSDisk = "$($tsenv.Value("OSDisk"))"
$OSDTargetSystemRoot = "$($tsenv.Value("OSDisk"))" + "\Windows"

########## Creating Log File ##########
$LogPath = "$OSDTargetSystemRoot\Temp\CustomizeWindowsOffline.log"
Start-Transcript -Path $LogPath

########## Copying new backgrounds ##########
Write-Host "Copying new backgrounds..."
# CompanyName Theme is created in the Oobe pass within the Unattend.xml file in MDT. The below background is specified within that.
Copy-Item $PSScriptRoot\CompanyName $OSDTargetSystemRoot\OEM\Themes\CompanyName -Recurse
Rename-Item $OSDTargetSystemRoot\Web\Screen\img100.jpg img106.jpg -Force
Copy-Item $PSScriptRoot\Lockscreen\img100.jpg $OSDTargetSystemRoot\Web\Screen

########## Load Default user hive ##########
Write-Host "Creating HKU Drive..." 
New-PSDrive HKU -Root HKEY_Users -PSProvider Registry
Write-Host "Loading Default user hive..."
REG LOAD HKU\Default $OSDisk\Users\Default\NTUSER.DAT

############ Computer Icon ##############
Write-Host "Adding Computer icon to desktop..."
#Registry key path 
$ICpath = "HKU:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
#Property name 
$ICname = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
#check if the property exists 
if (!(Test-Path $ICpath))
{
	#create a new property 
	New-Item -Path $ICpath -Force | Out-Null
	New-ItemProperty -Path $ICpath -Name $ICname -Value 0 -PropertyType DWORD -Force | Out-Null
}
Else
{
	#set property value 
	New-ItemProperty -Path $ICpath -Name $ICname -Value 0 -PropertyType DWORD -Force | Out-Null
}

############ Explorer Options ############
Write-Host "Setting Explorer options..." 
#Registry key path
$ExAdvPath = "HKU:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Write-Host "Unhiding File Extensions..." 
Set-ItemProperty -Path $ExAdvPath -Name "HideFileExt" -Value 0
Write-Host "Setting Explorer LaunchTo..." 
Set-ItemProperty -Path $ExAdvPath -Name "LaunchTo" -Value 1
Write-Host "Hiding Task View button"
Set-ItemProperty -Path $ExAdvPath -Name "ShowTaskViewButton" -Value 0
Write-Host "Left-aligning taskbar"
Set-ItemProperty -Path $ExAdvPath -Name "TaskbarAl" -Value 0
Write-Host "Removing Chat icon"
Set-ItemProperty -Path $ExAdvPath -Name "TaskbarMn" -Value 0

############ Disable Background compression ###########
Write-Host "Disabling background compression..."
$BGC = "HKU:\Default\Control Panel\Desktop"
New-ItemProperty -Path $BGC -Name "JPEGImportQuality" -Value 100 -PropertyType DWORD | Out-Null

###### Unload Default user hive ######
Write-Host "Unloading Default user hive..." 
$unloaded = $false
$attempts = 0
while (!$unloaded -and ($attempts -le 5))
{
	[gc]::Collect() # necessary call to be able to unload registry hive
	Start-Sleep -Seconds 5
	REG UNLOAD HKU\Default
	$unloaded = $?
	$attempts += 1
}
if (!$unloaded)
{
	Write-Warning "Unable to dismount default user registry hive at HKU\DEFAULT - Manual dismount required" 
}
Write-Host "Removing PS Drive..." 
Remove-PSDrive -Name HKU

############# Setting Custom Start and Taskbar #############
Write-Host "Setting Custom Start and Taskbar..."
# This is copying the start.bin file that was exported from a configured Windows 11.
Copy-Item $PSScriptRoot\start $OSDisk\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState -Recurse

############# Removing Unneeded Apps ###############
Write-Host "Removing Windows Mail..."
# May be no longer needed.
$mailapp = (Get-AppxProvisionedPackage -Path $OSDisk | ?{$_.PackageName -like "*windowscommunicationsapps*"}).PackageName
Remove-AppxProvisionedPackage -Path $OSDisk -PackageName $mailapp

Write-Host "Removing XBox..."
Get-AppxProvisionedPackage -Path $OSDisk | ?{$_.PackageName -like "*xbox*"} | ForEach-Object {Remove-AppxProvisionedPackage -Path $OSDisk -PackageName $_.PackageName}

#Write-Host "`r`n"
Write-Host "End of line."
Stop-Transcript