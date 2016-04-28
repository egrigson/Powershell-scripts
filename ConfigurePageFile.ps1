#input parameters
param([string] $csvPath, [Boolean] $sendEmailConfPage)

Write-Host "Beginning ConfigurePageFile.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailConfPage)

	if($sendEmailConfPage)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\ConfigurePageFile.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""4"">Configure PageFile Scripts</td></tr><tr class="Title"><td>Server</td><td>Script Run</td><td>Script Parameters</td><td>Script Result</td></tr>"
 
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
	if($sendEmailConfPage)
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

$Pagecsv = $csvPath + "\PageFile.csv"
$constantscsv = $csvPath + "\Constants.csv"

$Pagelist = Import-Csv $Pagecsv
$constantslist = Import-Csv $constantscsv

#$Pagelist | Format-Table -AutoSize
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
foreach ($server in $Pagelist)
{
   $result = ""
   #configure pagefile disks for windows servers
   if ($server."Automation Status" -match "Active")
   {
      if ($server."OS Type" -match "Windows")
      {
         Write-Host "Configuring Page File for" $server.Name
	     $pagefileDevice = $server."Page Guest Device"
	     $pagefileLetter = $server."PageFile Letter"
	     $pagefileLabel = $server."PageFile Label"
	     $ScriptText = "`"C:\post install tasks\ConfigureDisks.bat`" " + $pagefileDevice + " " + $pagefileLetter + " " + $pagefileLabel
   
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
		       $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	           $ReportItem.ServerName = $server.Name
			   $ReportItem.ScriptRun = "C:\post install tasks\ConfigureDisks.bat"
	           $ReportItem.Parameters = $pagefileDevice + " " + $pagefileLetter + " " + $pagefileLabel
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
		 
	           #Configure Pagefile
	           $pagefileSize = [int]$server."PageFile Size (MB)" - 100
	           $ScriptText = "`"C:\post install tasks\ConfigurePageFile.bat`" " + $pagefileSize + " " + $pagefileLetter
	   
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
				  Write-Host "Rebooting VM " $server.Name
			      Restart-VMGuest -VM $vm
			   }
			   $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
			   $ReportItem.ServerName = $server.Name
	           $ReportItem.ScriptRun = "C:\post install tasks\ConfigurePageFile.bat"
	           $ReportItem.Parameters = $server."PageFile Size (MB)" + " " + $pagefileLetter
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
			   
			   
	         }
	      } 
	   }
	
	   if ($server."OS Type" -match "Linux")
	   {
	      Write-Host "Configuring swap space for" $server.Name
	      $pagefileDevice = $server."Page Guest Device"
	      $ScriptText = "/root/scripts/configurePageFile.sh " + $pagefileDevice
	   
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
	        $ReportItem.ServerName = $server.Name
		    $ReportItem.ScriptRun = "/root/scripts/configurePageFile.sh"
	        $ReportItem.Parameters = $pagefileDevice
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
	      }
	   }
	}
	else
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
Disconnect-VIServer * -Confirm:$false | Out-Null

$EmailReport = Generate-Report $Report $errorReport $sendEmailConfPage

if ($sendEmailConfPage)
{
    #WriteHTML to file
   $outpath = $csvPath + "\ConfigurePageSwap" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Configure PageFile" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}