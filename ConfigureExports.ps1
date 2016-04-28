#input parameters
param([string] $csvPath,[Boolean] $sendEmailExports)

Write-Host "Beginning configurExports.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput, [Boolean] $sendEmailExports)

	if ($sendEmailExports)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\ConfigureExports.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""3"">Configure Volume Exports Report</td></tr><tr class="Title"><td>Volume Name</td><td>Export IPs</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
		if ($ReportItem.Result -match "Success") 
		{
			Write-Output "<tr style='color:green'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.ExportIPs)</td><td>$($ReportItem.Result)</td></tr> "
		} 
		else 
		{
			Write-Output "<tr style='color:red'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.ExportIPs)</td><td>$($ReportItem.Result)</td></tr> "
		}
	}
	Write-Output "</table><br>"
	write-output "<table><tr class=""Title""><td colspan=""2"">Configure Volumes Exports Errors</td></tr><tr class="Title"><td>Volume Name</td><td>Error Detail</td>"
 
	Foreach ($errorItem in $errorReportinput)
	{
        Write-Output "<tr style='color:black'><td>$($errorItem.VolumeName)</td><td>$($errorItem.ErrorDetail)</td>"
	}
	Write-Output "</table>"
	if ($sendEmailExports)
	{
	   write-output "</body></html>" 
	}
}
  
[array]$Report = "" | Select-Object VolumeName,ExportIPs,Result
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
   $Error.Clear()
   $result = ""
   if ($volume."Automation Status" -match "Active")
   {
      if ($volume."Access Type" -match "NFS")
      {
         Write-Host "Setting NFS Export Permissions for " $volume."Volume Name"
	  
	     Connect-NaController -Name $volume.Filer -Credential $mflnetcredential | Out-Null
	  
	     $volPath = "/vol/" + $volume."Volume Name"
	     $exportIPList = $volume."Mounted IPs"
	     $exportsArray = $exportIPList.split(":")
	  
	  
	     Set-NaNfsExport -Path $volPath `
	        -Persistent:$true `
	        -ReadWrite $exportsArray `
		    -Root $exportsArray `
		    -Confirm:$false | Out-Null
	  
	     if (!$?)
	     {
	        $result = "Error Setting Exports"
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
	     $ReportItem = "" | Select-Object VolumeName,ExportIPs,Result
	     $ReportItem.VolumeName = $volume."Volume Name"
	     $ReportItem.ExportIPs = $volume."Mounted IPs"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem
		 
	     Dismount-NaController | Out-Null
	   }
	}
	else
	{
	   if ($volume."Access Type" -match "NFS")
	   {
	     $result = "Automation Status Not Active"
		 $ReportItem = "" | Select-Object VolumeName,ExportIPs,Result
	     $ReportItem.VolumeName = $volume."Volume Name"
	     $ReportItem.ExportIPs = "N/A"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem 
	   }
	}
}

$EmailReport = Generate-Report $Report $errorReport $sendEmailExports


if ($sendEmailExports)
{
   #WriteHTML to file
   $outpath = $csvPath + "\configureexports" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "configure Exports Report" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}