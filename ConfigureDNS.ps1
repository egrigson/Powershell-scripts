#input parameters
param([string] $csvPath,[Boolean] $sendEmailDNS)

Write-Host "Beginning ConfigureDNS.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailDNS)

	if($sendEmailDNS)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\ConfigureDNS.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""4"">Configure DNS Script</td></tr><tr class="Title"><td>Server</td><td>Script Run</td><td>Script Parameters</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
		if ($ReportItem.Result -match "DNS Record Added") 
		{
			Write-Output "<tr style='color:green'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.ScriptRun)</td><td>$($ReportItem.Parameters)</td><td>$($ReportItem.Result)</td></tr> "
		} 
		else 
		{
			Write-Output "<tr style='color:red'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.ScriptRun)</td><td>$($ReportItem.Parameters)</td><td>$($ReportItem.Result)</td></tr> "
		}
	}
	Write-Output "</table><br>"
	if ($sendEmailDNS)
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

function Get-EncryptedText($text) {
    $Ptr=[System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($text)
    $unsecureString = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
	return $unsecureString
}

$serverscsv = $csvPath + "\servers.csv"
$constantscsv = $csvPath + "\Constants.csv"
$networkcsv = $csvPath + "\network.csv"

$serverslist = Import-Csv $serverscsv
$constantslist = Import-Csv $constantscsv
$networklist = Import-Csv $networkcsv

#$Pagelist | Format-Table -AutoSize
#$constantslist | Format-Table -AutoSize


#Get Constants
$vcServer = FindConstant $constantslist "VirtualCentre"
$mflnetUserName = FindConstant $constantslist "MFLNET username"
$mfltestUserName = FindConstant $constantslist "MFLTEST username"
$sysmanagerUserName = FindConstant $constantslist "localadmin username"
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
 
#Set Credentials esx
$esxcredentialFile = $csvPath + "\esx"
$esxPassword = Get-Content $esxcredentialFile | ConvertTo-SecureString
$esxcredential = New-Object System.Management.Automation.PsCredential `
   $esxUserName,$esxPassword
   


foreach ($server in $networklist)
{
   $result = ""
   #Add DNS records
   if ($server."Automation Status" -match "Active")
   {
      if ($server."OS Type" -match "Linux")
      {
         Write-Host "Adding DNS A record for" $server.Name "entry value is" $server."Builtin NIC IP"
		 
		 #Determine Domain
		 
		 $DNSfound = $false
		 foreach ($domainserver in $serverslist)
		 {
			if ($server.Name -match $domainserver.Name)
			{
			   
			   if ($domainserver."Template Customization To Duplicate" -match "Script Linux Template MFLTEST")
			   {
			      $DNSServer = "10.1.108.150"
				  $DNSDomain = "mfltest.co.uk"
				  $DNSUsername = $mfltestUsername
				  $DNScredential = $mfltestcredential
				  $DNSfound = $true
			   }
			   if ($domainserver."Template Customization To Duplicate" -match "Script Linux Template MFLNET")
			   {
			      $DNSServer = "10.1.100.150"
				  $DNSDomain = "mflnet.co.uk"
				  $DNSUsername = $mflnetUsername
				  $DNScredential = $mflnetcredential
				  $DNSfound = $true
			   }
			}
	     }
	     
		 if ($DNSfound = $false)
		 {
		    $result = "Error adding DNS record"
		    $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	        $ReportItem.ServerName = $server.Name
		    $ReportItem.ScriptRun = $DNSARecordName
	        $ReportItem.Parameters = "N/A"
	        $ReportItem.Result = "Problem determining DNS server"
	        $Report = $Report + $ReportItem
	     }
		 else
		 {
            $wmiclass = New-Object system.Management.ManagementScope
	        $wmiclass.path = "\\$DNSServer\root\MicrosoftDNS"
	  
	        $options = $wmiclass.Options
	        $options.Username = $DNSUsername
	        $options.Password = Get-EncryptedText $DNScredential.Password
	  
	        $wmiclass.Options = $options
	  
	        $wmiObject = New-Object system.Management.ManagementClass($wmiclass,'MicrosoftDNS_AType',$null)

            $DNSClass = 1
	        $DNSTTL = 3600
	  
	        $DNSARecordName = $server.Name + "." + $DNSDomain
	        $DNSARecordIP = $server."Builtin NIC IP"

            $wmiObject.CreateInstanceFromPropertyData($DNSServer,$DNSDomain,$DNSARecordName,$DNSClass,$DNSTTL,$DNSARecordIP) | Out-Null
	  
	        if (!$?)
	        {
	           $result = "Error adding DNS record"
		       $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	           $ReportItem.ServerName = $server.Name
		       $ReportItem.ScriptRun = $DNSARecordName
	           $ReportItem.Parameters = "N/A"
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
		 
            }
	        else
	        {
	           $result = "DNS Record Added"
	           $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
               $ReportItem.ServerName = $server.Name
		       $ReportItem.ScriptRun = $DNSARecordName
               $ReportItem.Parameters = "None"
               $ReportItem.Result = $result
               $Report = $Report + $ReportItem
		    }
	     }
	  }
   }
   else
   {
	   if ($server."OS Type" -match "Linux")
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

$EmailReport = Generate-Report $Report $errorReport $sendEmailDNS

if ($sendEmailDNS)
{
   #WriteHTML to file
   $outpath = $csvPath + "\ConfigureDNS" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Configure DNS" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}