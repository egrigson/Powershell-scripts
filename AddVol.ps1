#input parameters
param([string] $csvPath,[Boolean] $sendEmailaddVol)

Write-Host "Beginning AddVol.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput)

	if ($sendEmailaddVol)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	
	Write-Output "<p>Results of Powershell Function $($csvPath)\AddVols.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""5"">Add Volumes Results</td></tr><tr class="Title"><td>Volume Name</td><td>Filer Name</td><td>Aggregate</td><td>Volume Size</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
		if ($ReportItem.Result -match "Success") 
		{
			Write-Output "<tr style='color:green'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.FilerName)</td><td>$($ReportItem.Aggregate)</td><td>$($ReportItem.VolumeSize)</td><td>$($ReportItem.Result)</td></tr> "
		} 
		else 
		{
			Write-Output "<tr style='color:red'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.FilerName)</td><td>$($ReportItem.Aggregate)</td><td>$($ReportItem.VolumeSize)</td><td>$($ReportItem.Result)</td></tr> "
		}
	}
	Write-Output "</table><br>"
	write-output "<table><tr class=""Title""><td colspan=""2"">Add Volumes Errors</td></tr><tr class="Title"><td>Volume Name</td><td>Error Detail</td>"
 
	Foreach ($errorItem in $errorReportinput)
	{
        Write-Output "<tr style='color:black'><td>$($errorItem.VolumeName)</td><td>$($errorItem.ErrorDetail)</td>"
	}
	Write-Output "</table>"
	if($sendEmailaddVol)
	{
	   Write-output "</body></html>" 
	}
}
  
[array]$Report = "" | Select-Object VolumeName,FilerName,Aggregate,VolumeSize,Result
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
   if ($volume."Automation Status" -match "Active")
   {
      if ([int]$volume."Usable space required" -gt 0)
      {
	     Write-Host "Creating Volume" $volume."Volume Name" "of" $volume."Usable space required" "GB on" $volume.Filer
	     $Error.Clear()
	     $result = ""
	     Connect-NaController -Name $volume.Filer -Credential $mflnetcredential | Out-Null
	  
     	  $volumeSize = $volume."Volume size (Gb)" + "g"
	     New-NaVol -Name $volume."Volume Name" `
	        -Aggregate $volume."Aggregate" `
		    -Size $volumeSize `
		    -Confirm:$false | Out-Null
	      if (!$?)
	      {
	         $result = "Error with Volume Creation"
		     $errorReportItem = "" | Select-Object VolumeName,ErrorDetail
		     $errorReportItem.VolumeName = $volume."Volume Name"
		     $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		     $errorReport = $errorReport + $errorReportItem
		     $Error.Clear()
	      }
	      else
	      {
	         $result = "Success"
	      }
	   
	      $ReportItem = "" | Select-Object VolumeName,FilerName,Aggregate,VolumeSize,Result
	      $ReportItem.VolumeName = $volume."Volume Name"
	      $ReportItem.FilerName = $volume."Filer"
	      $ReportItem.Aggregate = $volume."Aggregate"
	      $ReportItem.VolumeSize = $volumeSize
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
		  $ReportItem = "" | Select-Object VolumeName,FilerName,Aggregate,VolumeSize,Result
	      $ReportItem.VolumeName = $volume."Volume Name"
	      $ReportItem.FilerName = "N/A"
	      $ReportItem.Aggregate = "N/A"
	      $ReportItem.VolumeSize = "N/A"
	      $ReportItem.Result = $result
	      $Report = $Report + $ReportItem
	   }
	}
}

$EmailReport = Generate-Report $Report $errorReport $sendEmailaddVol


if($sendEmailaddVol)
{
   #WriteHTML to file
   $outpath = $csvPath + "\AddVol" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Add Volumes Report" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}