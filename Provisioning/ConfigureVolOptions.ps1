#input parameters
param([string] $csvPath,[Boolean] $sendEmailvoloptions)

Write-Host "Beginning configurevoloptions.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailvoloptions)

	if($sendEmailvoloptions)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\ConfigureVolOptions.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""7"">ConfigureVolOptions Report</td></tr><tr class="Title"><td>Volume Name</td><td>SnapReserve</td><td>NoSnap Set</td><td>No Atime Update On</td><td>Dedupe Enabled</td><td>Dedupe Start Time</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
		if ($ReportItem.Result -match "Success") 
		{
			Write-Output "<tr style='color:green'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.SnapReserve)</td><td>$($ReportItem.NoSnap)</td><td>$($ReportItem.atime)</td><td>$($ReportItem.Dedup)</td><td>$($ReportItem.DedupTime)</td><td>$($ReportItem.Result)</td></tr> "
		} 
		else 
		{
			Write-Output "<tr style='color:red'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.SnapReserve)</td><td>$($ReportItem.NoSnap)</td><td>$($ReportItem.atime)</td><td>$($ReportItem.Dedup)</td><td>$($ReportItem.DedupTime)</td><td>$($ReportItem.Result)</td></tr> "
		}
	}
	Write-Output "</table><br>"
	write-output "<table><tr class=""Title""><td colspan=""2"">Configure Volumes Errors</td></tr><tr class="Title"><td>Volume Name</td><td>Error Detail</td>"
 
	Foreach ($errorItem in $errorReportinput)
	{
        Write-Output "<tr style='color:black'><td>$($errorItem.VolumeName)</td><td>$($errorItem.ErrorDetail)</td>"
	}
	Write-Output "</table>"
	if($sendEmailvoloptions)
	{
	   write-output "</body></html>" 
	}
}
  
[array]$Report = "" | Select-Object VolumeName,SnapReserve,NoSnap,atime,Dedup,DedupTime,Result
[array]$errorReport = "" | Select-Object VolumeName,ErrorDetail
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
$mflnetUserName = FindConstant $constantslist "MFLNET username"
$EmailTo = FindConstant $constantslist "Email To"
$EmailFrom = FindConstant $constantslist "Email From"
$EmailServer = FindConstant $constantslist "Email Server"

#Set Credentials
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword
   
foreach ($volume in $netappVolslist)
{
   $result = ""
   $Error.Clear()
   $noAtime = "False"
   $volDedupSchedule = ""
   
   if ($volume."Automation Status" -match "Active")
   {
      if ([int]$volume."Usable space required" -gt 0)
      {
         Write-Host "Setting Vol Options for " $volume."Volume Name"
	  
	     $Error.Clear()
	     Connect-NaController -Name $volume.Filer -Credential $mflnetcredential | Out-Null
	  
	     $volPath = "/vol/" + $volume."Volume Name"
	  
	     #Set Snap reserve
	     Set-NaSnapshotReserve -Name $volume."Volume Name" `
	        -Percentage $volume."Snap reserve %" `
		    -Confirm:$false | Out-Null
		 
	     if (!$?)
	     {
	         $result = "Error with setting Snapshot Reserve"
		     $errorReportItem = "" | Select-Object VolumeName,ErrorDetail
		     $errorReportItem.VolumeName = $volume."Volume Name"
		     $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		     $errorReport = $errorReport + $errorReportItem
		     $Error.Clear()
	     }
	  
         #Disable snapshot schedule
	     Set-NaVolOption -Name $volume."Volume Name" `
	        -Key "nosnap" `
		    -Value "on" `
		    -Confirm:$false | Out-Null
	  
	     if (!$?)
	     {
	         $result = $result + "Error with setting vol no snap"
		     $errorReportItem = "" | Select-Object VolumeName,ErrorDetail
		     $errorReportItem.VolumeName = $volume."Volume Name"
		     $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		     $errorReport = $errorReport + $errorReportItem
		     $Error.Clear()
	     }
	  
	     #Set atime option for vmware volumes
	     if ($volume."Volume Purpose" -match "VMWare")
	     {
    	     Set-NaVolOption -Name $volume."Volume Name" `
	    	   -Key "no_atime_update" `
	    	   -Value "on" `
			   -Confirm:$false | Out-Null
			
		   if (!$?)
	       {
	         $result = $result + "Error with Setting no_atime_update"
		     $errorReportItem = "" | Select-Object VolumeName,ErrorDetail
		     $errorReportItem.VolumeName = $volume."Volume Name"
		     $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		     $errorReport = $errorReport + $errorReportItem
		     $Error.Clear()
	       }
		   else
		   {
		      $noAtime = "True"
		   }
	     }
	  
	     #Set DeDupe
	     if ($volume.Dedupe -match "Yes")
	     {
 		    $volDedupSchedule = "sun-sat@" + $volume."Dedup Start Time"
		 
		    Enable-NaSis -Path $volPath `
		       -Confirm:$false | Out-Null
		
		   if (!$?)
	       {
	          $result = $result + "Error with Enabling Dedupe"
		      $errorReportItem = "" | Select-Object VolumeName,ErrorDetail
		      $errorReportItem.VolumeName = $volume."Volume Name"
		      $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		      $errorReport = $errorReport + $errorReportItem
		      $Error.Clear()
	       }

		   Set-NaSis -Path $volPath `
		    -Schedule $volDedupSchedule `
			-Confirm:$false | Out-Null
		
		   if (!$?)
	       {
	         $result = $result + "Error with setting dedupe time"
		     $errorReportItem = "" | Select-Object VolumeName,ErrorDetail
		     $errorReportItem.VolumeName = $volume."Volume Name"
		     $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		     $errorReport = $errorReport + $errorReportItem
		     $Error.Clear()
	       }
         }
	  
	     if ($result -match "")
	     {
	        $result = "Success"
	     }
	  
	     $ReportItem = "" | Select-Object VolumeName,SnapReserve,NoSnap,atime,Dedup,DedupTime,Result
	     $ReportItem.VolumeName = $volume."Volume Name"
	     $ReportItem.SnapReserve = $volume."Snap reserve %"
	     $ReportItem.NoSnap = "Enabled"
	     $ReportItem.atime = $noAtime
	     $ReportItem.Dedup = $volume.Dedupe
	     $ReportItem.DedupTime = $volDedupSchedule
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem
	  
	     Dismount-NaController | Out-Null
      }
   }
   else
   {
      if ([int]$volume."Usable space required" -gt 0)
	  {
	     $result = "Automation Status Not Active"
		 $ReportItem = "" | Select-Object VolumeName,SnapReserve,NoSnap,atime,Dedup,DedupTime,Result
	     $ReportItem.VolumeName = $volume."Volume Name"
	     $ReportItem.SnapReserve = "N/A"
	     $ReportItem.NoSnap = "N/A"
	     $ReportItem.atime = "N/A"
	     $ReportItem.Dedup = "N/A"
	     $ReportItem.DedupTime = "N/A"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem
	   }
	}
}

$EmailReport = Generate-Report $Report $errorReport $sendEmailvoloptions


if($sendEmailvoloptions)
{
   #WriteHTML to file
   $outpath = $csvPath + "\configurevoloptions" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Configure Volume Options" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}