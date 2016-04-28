#input parameters
param([string] $csvPath, [Boolean] $sendEmailconfFSTAB)

Write-Host "Beginning ConfigureFSTAB.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput, [Boolean] $sendEmailconfFSTAB)

	if ($sendEmailconfFSTAB)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\ConfigureFSTAB.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""4"">Configure FSTAB Scripts</td></tr><tr class="Title"><td>Server</td><td>Script Run</td><td>Script Parameters</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
		if ($ReportItem.Result -match "Script run on guest") 
		{
			Write-Output "<tr style='color:green'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.ScriptRun)</td><td>$($ReportItem.Parameters)</td><td>$($ReportItem.Result)</td></tr> "
		} 
		else 
		{
			Write-Output "<tr style='color:red'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.ScriptRun)</td><td>$($ReportItem.Parameters)</td><td>$($ReportItem.Result)</td></tr> "
		}
	}
	Write-Output "</table><br>"
	if ($sendEmailconfFSTAB)
	{
	   write-output "</body></html>"
	}
}
  
[array]$Report = "" | Select-Object ServerName,ScriptRun,Parameters,Result

#################End Prepare Report######################################

function Send-SMTPmail($to, $from, $subject, $smtpserver, $body) {
	$mailer = new-object Net.Mail.SMTPclient($smtpserver)
	$msg = new-object Net.Mail.MailMessage($from,$to,$subject,$body)
	$msg.IsBodyHTML = $true
	$mailer.send($msg)
}

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

# $servercsv is the input file

$netappVolscsv = $csvPath + "\NetappVols.csv"
$constantscsv = $csvPath + "\Constants.csv"

$netappVolslist = Import-Csv $netappVolscsv
$constantslist = Import-Csv $constantscsv

#Get Constants
$vcServer = FindConstant $constantslist "VirtualCentre"
$mflnetUserName = FindConstant $constantslist "MFLNET username"
$mfltestUserName = FindConstant $constantslist "MFLTEST username"
$sysmanagerUserName = FindConstant $constantslist "localadmin username"
$linuxRootUserName = FindConstant $constantslist "linux root"
$esxUserName = FindConstant $constantslist "esx root"
$EmailTo = FindConstant $constantslist "Email To"
$EmailFrom = FindConstant $constantslist "Email From"
$EmailServer = FindConstant $constantslist "Email Server"

#Set Credentials mflnet
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword

#Set Credentials mfltest
$mfltestcredentialFile = $csvPath + "\mfltest"
$mfltestPassword = Get-Content $mfltestcredentialFile | ConvertTo-SecureString
$mfltestcredential = New-Object System.Management.Automation.PsCredential `
   $mfltestUserName,$mfltestPassword

#Set Credentials sysmanager
$sysmanagercredentialFile = $csvPath + "\sysmanager"
$sysmanagerPassword = Get-Content $sysmanagercredentialFile | ConvertTo-SecureString
$sysmanagercredential = New-Object System.Management.Automation.PsCredential `
   $sysmanagerUserName,$sysmanagerPassword
   
#Set Credentials linuxRoot
$linuxRootFile = $csvPath + "\linuxRoot"
$linuxRootPassword = Get-Content $linuxRootFile | ConvertTo-SecureString
$linuxRootcredential = New-Object System.Management.Automation.PsCredential `
   $linuxRootUserName,$linuxRootPassword
 
#Set Credentials esx
$esxcredentialFile = $csvPath + "\esx"
$esxPassword = Get-Content $esxcredentialFile | ConvertTo-SecureString
$esxcredential = New-Object System.Management.Automation.PsCredential `
   $esxUserName,$esxPassword
   
Connect-VIServer $vcServer -Credential $mflnetcredential | Out-Null


foreach ($volume in $netappVolslist)
{
   if ($volume."Automation Status" -match "Active")
   {
      if ($volume."Access Type" -match "NFS" -and $volume."Volume Purpose" -match "Linux NFS")
      {
	  
	     $serversList = $volume."Mounted on servers"
	     $serversArray = $serversList.split(":")
	  
	     foreach ($server in $serversArray)
	     {
	        Write-Host "Writing FSTAB entries" $volume."Volume Name" "on" $server
		 
		    #Get VM
	        $vm = Get-VM -Name $server
		    if (!$?)
	        {
	           $result = "Error Finding VM"
		       $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	           $ReportItem.ServerName = $server
		       $ReportItem.ScriptRun = "N/A"
	           $ReportItem.Parameters = "N/A"
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
		 
            }
	        else
	        {
	  
	           $mountPoint = $volume."Mount point"
	           $fstabEntry = $volume."/etc/fstab entry"
	           $ScriptText = "/root/scripts/configureFSTAB.sh " + $mountPoint + " " + "`"" + $fstabEntry + "`""
	  
	           Invoke-VMScript -ScriptText $ScriptText `
		          -VM $vm `
		          -ScriptType "Bash" `
		          -GuestCredential $linuxRootcredential `
		          -HostCredential $esxcredential | Out-Null
			   
		    
			   if (!$?)
		       {
		          $result = "Script failed to run"
	           }
		       else
		       {
		          $result = "Script run on guest"
	           }
			
			   $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	           $ReportItem.ServerName = $server
		       $ReportItem.ScriptRun = "/root/scripts/configureFSTAB.sh"
	           $ReportItem.Parameters = $mountPoint + " " + "`"" + $fstabEntry + "`""
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
		    }
	      }
		 
	   }
	}
	else
	{
	   if ($volume."Access Type" -match "NFS" -and $volume."Volume Purpose" -match "Linux NFS")
	   {
	      $result = "Automation Status Not Active"
		  $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	      $ReportItem.ServerName = $server
		  $ReportItem.ScriptRun = "N/A"
	      $ReportItem.Parameters = "N/A"
	      $ReportItem.Result = $result
	      $Report = $Report + $ReportItem
	   }
   }
}
Disconnect-VIServer * -Confirm:$false | Out-Null

$EmailReport = Generate-Report $Report $errorReport $sendEmailconfFSTAB

if($sendEmailconfFSTAB)
{
   #WriteHTML to file
   $outpath = $csvPath + "\ConfigureFSTAB" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Configure FSTAB" $EmailServer $EmailReport
   
    Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}