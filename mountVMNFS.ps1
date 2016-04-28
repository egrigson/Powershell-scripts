#input parameters
param([string] $csvPath, [Boolean] $sendEmailMount)

Write-Host "Beginning mountVMNFS.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailMount)

	if ($sendEmailMount)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\mountVMNFS.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""3"">Mount VM NFS Datastores</td></tr><tr class="Title"><td>Volume Name</td><td>Mounted On</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
		if ($ReportItem.Result -match "Success") 
		{
			Write-Output "<tr style='color:green'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.MountedServers)</td><td>$($ReportItem.Result)</td></tr> "
		} 
		else 
		{
			Write-Output "<tr style='color:red'><td>$($ReportItem.VolumeName)</td><td>$($ReportItem.MountedServers)</td><td>$($ReportItem.Result)</td></tr> "
		}
	}
	Write-Output "</table><br>"
	write-output "<table><tr class=""Title""><td colspan=""2"">Mount VM NFS Datastores Errors</td></tr><tr class="Title"><td>Volume Name</td><td>Error Detail</td>"
 
	Foreach ($errorItem in $errorReportinput)
	{
        Write-Output "<tr style='color:black'><td>$($errorItem.VolumeName)</td><td>$($errorItem.ErrorDetail)</td>"
	}
	Write-Output "</table>"
	if($sendEmailMount)
	{
	   write-output "</body></html>" 
	}
}
  
[array]$Report = "" | Select-Object VolumeName,MountedServers,Result
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


$netappVolscsv = $csvPath + "\NetappVols.csv"
$constantscsv = $csvPath + "\Constants.csv"

$netappVolslist = Import-Csv $netappVolscsv
$constantslist = Import-Csv $constantscsv

#Get Constants
$mflnetUserName = FindConstant $constantslist "MFLNET username"
$vcServer = FindConstant $constantslist "VirtualCentre"
$EmailTo = FindConstant $constantslist "Email To"
$EmailFrom = FindConstant $constantslist "Email From"
$EmailServer = FindConstant $constantslist "Email Server"

#Set Credentials
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword
   
#Added EG, 18th Sept 2012. Avoids an error ('Could not connect using the requested protocol') 
#when a proxy is configured by disabling proxy settings for this PowerCLI session
Set-PowerCLIConfiguration -ProxyPolicy NoProxy -Confirm:$false

Connect-VIServer $vcServer -Credential $mflnetcredential -WarningAction SilentlyContinue | Out-Null
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
foreach ($volume in $netappVolslist)
{
   $Error.Clear()
   $result = ""
   if ($volume."Automation Status" -match "Active")
   {
      if ($volume."Access Type" -match "NFS" -and $volume."Volume Purpose" -match "VMWare")
      {
         Write-Host "Mounting NFS Volume" $volume."Volume Name" "to vmware hosts"
	  
	     
	  
   	     $volPath = "/vol/" + $volume."Volume Name"
	     $hostList = $volume."Mounted on servers"
	     $hostArray = $hostList.split(":")
	  
	     foreach ($vmhost in $hostArray)
		 {
		    
		    Get-VMHost $vmhost | New-Datastore -Name $volume."VMWare Datastore Name" `
		       -Nfs `
		       -NfsHost $volume."Filer NFS Access IP" `
		       -Path $volPath | Out-Null
		 }
	  
	     if (!$?)
	     {
	        $result = "Error Mounting Datastore"
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
	     $ReportItem = "" | Select-Object VolumeName,MountedServers,Result
	     $ReportItem.VolumeName = $volume."Volume Name"
	     $ReportItem.MountedServers = $volume."Mounted on servers"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem
	   }  
   }
   else
   {
      if ($volume."Access Type" -match "NFS" -and $volume."Volume Purpose" -match "VMWare")
	  {
	     $result = "Automation Status Not Active"
		 $ReportItem = "" | Select-Object VolumeName,MountedServers,Result
	     $ReportItem.VolumeName = $volume."Volume Name"
	     $ReportItem.MountedServers = "N/A"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem
      }
   }
   
}
Disconnect-VIServer * -Confirm:$false | Out-Null

$EmailReport = Generate-Report $Report $errorReport $sendEmailMount


if ($sendEmailMount)
{
   #WriteHTML to file
   $outpath = $csvPath + "\mountVMNFS" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Mount VM Datastores" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-output $EmailReport
   Write-Host "Script Completed"
}