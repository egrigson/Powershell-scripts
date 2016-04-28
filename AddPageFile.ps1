param([string] $csvPath, [Boolean] $sendEmailaddpage)

Write-Host "Beginning AddPageFile.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailaddpage)

   if ($sendEmailaddpage)
   {
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
   }
   Write-Output "<p>Results of Powershell Function $($csvPath)\AddPageFile.ps1 run on $($date)"
   write-output "<table><tr class=""Title""><td colspan=""4"">Add Page File Disks</td></tr><tr class="Title"><td>Server</td><td>PageFile Datastore</td><td>PageFile Size MB</td><td>Script Result</td></tr>"
 
   Foreach ($ReportItem in $Reportinput)
   {
      if ($ReportItem.Result -match "Success") 
      {
	     Write-Output "<tr style='color:green'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.PageFileDatastore)</td><td>$($ReportItem.PageFileSize)</td><td>$($ReportItem.Result)</td></tr> "
      } 
      else 
      {
         Write-Output "<tr style='color:red'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.PageFileDatastore)</td><td>$($ReportItem.PageFileSize)</td><td>$($ReportItem.Result)</td></tr> "
      }
   }
   Write-Output "</table><br>"
	
   write-output "<table><tr class=""Title""><td colspan=""2"">Add Page File Disks Errors</td></tr><tr class="Title"><td>Server Name</td><td>Error Detail</td>"
 
   Foreach ($errorItem in $errorReportinput)
   {
      Write-Output "<tr style='color:black'><td>$($errorItem.ServerName)</td><td>$($errorItem.ErrorDetail)</td>"
   }
   Write-Output "</table>"
   if($sendEmailaddpage)
   {
      Write-Output "</body></html>" 
   }
}
  
[array]$Report = "" | Select-Object ServerName,PageFileDatastore,PageFileSize,Result
[array]$errorReport = "" | Select-Object ServerName,ErrorDetail
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
$EmailTo = FindConstant $constantslist "Email To"
$EmailFrom = FindConstant $constantslist "Email From"
$EmailServer = FindConstant $constantslist "Email Server"

#Set Credentials mflnet
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword
   
Connect-VIServer $vcServer -Credential $mflnetcredential | Out-Null

foreach ($server in $Pagelist)
{
    $Error.Clear()
	$result=""
	if ($server."Automation Status" -match "Active")
	{

         Write-Host "Adding Page/Swap Disk to" $server.Name
	  
	     $vm = Get-VM -Name $server.Name
	     if (!$?)
	     {
	         $result = "Error Finding VM"
	         $errorReportItem = "" | Select-Object ServerName,ErrorDetail
             $errorReportItem.ServerName = $server."Name"
	         $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
	         $errorReport = $errorReport + $errorReportItem
	         $Error.Clear()
	     }
	     else
	     {
	        $pageFileCapacity = [int64]$server."PageFile Size (MB)" * 1024
			$pageDatastore = Get-Datastore -Name $server."PageFile Datastore" -Datacenter $server.Datacentre
	        New-HardDisk -VM $vm `
		   	   -Datastore $pageDatastore `
			   -Persistence "Persistent" `
			   -DiskType "flat" `
			   -CapacityKB $pageFileCapacity | Out-Null
	
	         if (!$?)
	         {
	            $result = "Error adding PageDisk"
	            $errorReportItem = "" | Select-Object ServerName,ErrorDetail
                $errorReportItem.ServerName = $server."Name"
	            $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
	            $errorReport = $errorReport + $errorReportItem
	            $Error.Clear()
	         }
	         else
	         {
      	         $result = "Success"
	         }
	      }
	
	      $ReportItem = "" | Select-Object ServerName,PageFileDatastore,PageFileSize,Result
	      $ReportItem.ServerName = $server."Name"
	      $ReportItem.PageFileDatastore = $server."PageFile Datastore"
	      $ReportItem."PageFileSize" = $server."PageFile Size (MB)"
	      $ReportItem.Result = $result
	      $Report = $Report + $ReportItem
	}
	else
	{

	      $result = "Automation Status Not Active"
		  $ReportItem = "" | Select-Object ServerName,PageFileDatastore,PageFileSize,Result
	      $ReportItem.ServerName = $server."Name"
	      $ReportItem.PageFileDatastore = "N/A"
	      $ReportItem."PageFileSize" = "N/A"
	      $ReportItem.Result = $result
	      $Report = $Report + $ReportItem

	}
}

Disconnect-VIServer * -Confirm:$false

$EmailReport = Generate-Report $Report $errorReport $sendEmailaddpage

if($sendEmailaddpage)
{
   #WriteHTML to file
   $outpath = $csvPath + "\AddPageFile" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Add PageFile Disks" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}