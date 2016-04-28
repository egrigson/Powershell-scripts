param([string] $csvPath,[Boolean] $sendEmailadddisk)

Write-Host "Beginning AddDisks.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailadddisk)

	if ($sendEmailadddisk)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\AddDisks.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""5"">Add Additional Disks</td></tr><tr class="Title"><td>Server</td><td>Additional Disk No</td><td>Additional Disk Datastore</td><td>Additional Disk Size GB</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
		if ($ReportItem.Result -match "Success") 
		{
			Write-Output "<tr style='color:green'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.AdditionalDiskNo)</td><td>$($ReportItem.AdditionalDiskDatastore)</td><td>$($ReportItem.AdditionalDiskSize)</td><td>$($ReportItem.Result)</td></tr> "
		} 
		else 
		{
			Write-Output "<tr style='color:red'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.AdditionalDiskNo)</td><td>$($ReportItem.AdditionalDiskDatastore)</td><td>$($ReportItem.AdditionalDiskSize)</td><td>$($ReportItem.Result)</td></tr> "
		}
	}
	Write-Output "</table><br>"
	write-output "<table><tr class=""Title""><td colspan=""3"">Add Additional disks Errors</td></tr><tr class="Title"><td>Server Name</td><td>Error Detail</td>"
 
	Foreach ($errorItem in $errorReportinput)
	{
        Write-Output "<tr style='color:black'><td>$($errorItem.ServerName)</td><td>$($errorItem.AdditionalDiskNo)</td><td>$($errorItem.ErrorDetail)</td>"
	}
	Write-Output "</table>"
	if($sendEmailadddisk)
	{
	   Write-Output "</body></html>"
	}
}
  
[array]$Report = "" | Select-Object ServerName,AdditionalDiskNo,AdditionalDiskDatastore,AdditionalDiskSize,Result
[array]$errorReport = "" | Select-Object ServerName,AdditionalDiskNo,ErrorDetail
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

$Diskscsv = $csvPath + "\Disks.csv"
$constantscsv = $csvPath + "\Constants.csv"

$Diskslist = Import-Csv $Diskscsv
$constantslist = Import-Csv $constantscsv

#$Diskslist | Format-Table -AutoSize
#$constantslist | Format-Table -AutoSize

#Get Constants
$vcServer = FindConstant $constantslist "VirtualCentre"
$mflnetUserName = FindConstant $constantslist "MFLNET username"
$EmailTo = FindConstant $constantslist "Email To"
$EmailFrom = FindConstant $constantslist "Email From"
$EmailServer = FindConstant $constantslist "Email Server"

#Set Credentials mflnet
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword
   
Connect-VIServer $vcServer -Credential $mflnetcredential | Out-Null

foreach ($server in $Diskslist)
{
    $Error.Clear()
	$result = ""
	if ($server."Automation Status" -match "Active")
	{
      if ($server."Total New Drives Count" -gt 0)
      {
	     $drivesAdded = 0
	  
	     #Get VM
	     $vm = Get-VM -Name $server.Name
	     if (!$?)
	     {
	        $result = "Error Finding VM"
	        $errorReportItem = "" | Select-Object ServerName,AdditionalDiskNo,ErrorDetail
            $errorReportItem.ServerName = $server."Name"
		    $errorReportItem.AdditionalDiskNo = "N/A"
	        $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
	        $errorReport = $errorReport + $errorReportItem
	        $Error.Clear()
		 
		    $ReportItem = "" | Select-Object ServerName,AdditionalDiskNo,AdditionalDiskDatastore,AdditionalDiskSize,Result
	        $ReportItem.ServerName = $server."Name"
	        $ReportItem.AdditionalDiskNo = "N/A"
		    $ReportItem.AdditionalDiskDatastore = "N/A"
		    $ReportItem.AdditionalDiskSize = "N/A"
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
         }
	     else
	     {
 	        while ($drivesAdded -lt $server."Total New Drives Count" )
	        {
	           $drivesAdded = $drivesAdded + 1
		        Write-Host "Adding Additional Disk" $drivesAdded "to" $server.Name
			   $newDatastore = "New Drive" + $drivesAdded + " Datastore"
		       $newCapacitystr = "New Drive" + $drivesAdded + " Size (GB)"
		       $newCapacity = [int64]$server.$newCapacitystr * 1024 * 1024
		       $vmDatastore = Get-Datastore -Name $server.$newDatastore -Datacenter $server.Datacentre		   
			   New-HardDisk -VM $vm `
			      -Datastore $vmDatastore `
			      -Persistence "Persistent" `
			      -DiskType "flat" `
			      -CapacityKB $newCapacity | Out-Null
 			   
			   if (!$?)
			   {
 			      $result = "Error adding Disk"
	              $errorReportItem = "" | Select-Object ServerName,AdditionalDiskNo,ErrorDetail
                  $errorReportItem.ServerName = $server."Name"
		          $errorReportItem.AdditionalDiskNo = $drivesAdded
	              $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
	              $errorReport = $errorReport + $errorReportItem
	              $Error.Clear()
			   }
			   else
			   {
			      $result = "Success"
			   }
			
			   $ReportItem = "" | Select-Object ServerName,AdditionalDiskNo,AdditionalDiskDatastore,AdditionalDiskSize,Result
	           $ReportItem.ServerName = $server."Name"
	           $ReportItem.AdditionalDiskNo = $drivesAdded
		       $ReportItem.AdditionalDiskDatastore = $server.$newDatastore
		       $ReportItem.AdditionalDiskSize = $server.$newCapacitystr
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
	        }
         }
      }
   }
   else
   {
      if ($server."Total New Drives Count" -gt 0)
	  {
	     $result = "Automation Status Not Active"
		 $ReportItem = "" | Select-Object ServerName,AdditionalDiskNo,AdditionalDiskDatastore,AdditionalDiskSize,Result
	     $ReportItem.ServerName = $server."Name"
	     $ReportItem.AdditionalDiskNo = "N/A"
		 $ReportItem.AdditionalDiskDatastore = "N/A"
		 $ReportItem.AdditionalDiskSize = "N/A"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem 
	  }
   }
}

Disconnect-VIServer * -Confirm:$false

$EmailReport = Generate-Report $Report $errorReport $sendEmailadddisk

if($sendEmailadddisk)
{
   #WriteHTML to file
   $outpath = $csvPath + "\AddDisks" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Add Additional Disks" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}