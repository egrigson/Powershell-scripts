#input parameters
param([string] $csvPath)

Write-Host "Beginning PowerOnVMs.psl Script"

function FindConstant {
param([Object]$constantsarray,[String]$constantToFind)

   foreach ($constant in $constantsarray)
   {
   
      if ($constant -match $constantToFind)
	  {
	     return $constant.Value
      }
   }
   return "Constant Not Found"
}


$servercsv = $csvPath + "\Servers.csv"
$constantscsv = $csvPath + "\Constants.csv"

$serverlist = Import-Csv $servercsv
$constantslist = Import-Csv $constantscsv

#$serverlist | Format-Table -Autosize

#$constantslist | Format-Table -AutoSize
  
#Get Constants
$vcServer = FindConstant $constantslist "VirtualCentre"
$mflnetUserName = FindConstant $constantslist "MFLNET username"

#Set Credentials
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword
   
   #connect Virtual Centre
Connect-VIServer $vcServer -Credential $mflnetcredential | Out-Null

$count = 0
foreach ($server in $serverlist) 
{ 
    if ($server."Automation Status" -match "Active")
	{
	   if ($server."Type" -match "Virtual" )
	   { 
	      
		  $vm = Get-VM -Name $server.Name
	  
	      if($vm.PowerState -eq "PoweredOff")
	      {
	          Write-Host "Powering On" $server.Name
		      Start-VM -VM $vm -Confirm:$false | Out-Null
			  $count = $count + 1
	      }
	   }
	}
	if ($count -gt 5)
	{
	   Write-Host "Sleeping 2mins to prevent host congestion"
	   sleep 120
	   $count = 0
	}
}
Disconnect-VIServer * -Confirm:$false | Out-Null