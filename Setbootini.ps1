#input parameters
param([string] $csvPath, [Boolean] $sendEmailSetboot)

Write-Host "Beginning SetBootini.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput, [Boolean] $sendEmailSetboot)

	if ($sendEmailSetboot)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\SetBootini.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""4"">Set boot.ini Scripts</td></tr><tr class="Title"><td>Server</td><td>Script Run</td><td>Script Parameters</td><td>Script Result</td></tr>"
 
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
	if ($sendEmailSetboot)
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

$servercsv = $csvPath + "\servers.csv"
$constantscsv = $csvPath + "\Constants.csv"

$serverlist = Import-Csv $servercsv
$constantslist = Import-Csv $constantscsv

#$Diskslist | Format-Table -AutoSize
#$constantslist | Format-Table -AutoSize


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
foreach ($server in $serverlist)
{
   $result = ""
   #Install Agents
	if ($server."Automation Status" -match "Active")
	{
	   if ($server."Template" -match "W2k3 r2 Ent x32 Script" -or $server."Template" -match "W2k3 r2 Ent x64 Script")
	   {
	     Write-Host "Resetting boot.ini for" $server.Name
	     #Get VM
	     $vm = Get-VM -Name $server.Name
	     if (!$?)
	     {
	        $result = "Error Finding VM"
		    $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	        $ReportItem.ServerName = $server.Name
		    $ReportItem.ScriptRun = "N/A"
	        $ReportItem.Parameters = "N/A"
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
		 
         }
	     else
	     {
            $ScriptText = "`"C:\post install tasks\Setbootini.bat`""

		    Invoke-VMScript -ScriptText $ScriptText `
		       -VM $vm `
		       -ScriptType "Bat" `
		       -GuestCredential $sysmanagercredential `
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
	        $ReportItem.ServerName = $server.Name
			$ReportItem.ScriptRun = "C:\post install tasks\Setbootini.bat"
	        $ReportItem.Parameters = "None"
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
		}
      }
	}
	else
	{
	   if ($server."OS Type" -match "Windows")
	   {
	     $result = "Automation Status Not Active"
		 $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	     $ReportItem.ServerName = $server.Name
		 $ReportItem.ScriptRun = "N/A"
	     $ReportItem.Parameters = "N/A"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem 
	   }
	}
}
Disconnect-VIServer * -Confirm:$false | Out-Null

$EmailReport = Generate-Report $Report $errorReport $sendEmailSetboot

if ($sendEmailSetboot)
{
   #WriteHTML to file
   $outpath = $csvPath + "\SetBootini" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Install Agents" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Output $EmailReport
}