#input parameters
param([string] $csvPath)

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

$Clonescsv = $csvPath + "\Clones.csv"
$constantscsv = $csvPath + "\Constants.csv"

$Cloneslist = Import-Csv $Clonescsv
$constantslist = Import-Csv $constantscsv

#$Cloneslist | Format-Table -AutoSize
#$constantslist | Format-Table -AutoSize

#Get Constants
$vcServer = FindConstant $constantslist "VirtualCentre"
$mflnetUserName = FindConstant $constantslist "MFLNET username"

#Set Credentials mflnet
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword
   
Connect-VIServer $vcServer -Credential $mflnetcredential -Verbose  #| Out-Null

foreach ($server in $Cloneslist)
{
   if ($server."Total Cloned Drives" -gt 0)
   {
      $clonesAdded = 0
	  #Get VM
	  $vm = Get-VM -Name $server.Name
	  
	  while ($clonesAdded -lt $server."Total Cloned Drives" )
	  {
	     $clonesAdded = $clonesAdded + 1
		 $clonePath = "Clone" + $clonesAdded + " Path"
		 New-HardDisk -VM `
		    -DiskPath $clonePath
	  }
   }
}