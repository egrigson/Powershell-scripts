#input parameters
param([string] $csvPath,[Boolean] $sendEmailaddnic)

Write-Host "Beginning AddNics.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput, $sendEmailaddnic)

	if($sendEmailaddnic)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\AddNics.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""4"">Add Additional Nics</td></tr><tr class="Title"><td>Server</td><td>Additional Nic No</td><td>Additional Nic VM Network</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
	   if ($ReportItem.Result -match "Success") 
	   {
	      Write-Output "<tr style='color:green'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.AdditionalNicNo)</td><td>$($ReportItem.AdditionalNicVMNetwork)</td><td>$($ReportItem.Result)</td></tr> "
	   } 
	   else 
	   {
	      Write-Output "<tr style='color:red'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.AdditionalNicNo)</td><td>$($ReportItem.AdditionalNicVMNetwork)</td><td>$($ReportItem.Result)</td></tr> "
	   }
	}
	Write-Output "</table><br>"
	write-output "<table><tr class=""Title""><td colspan=""3"">Add Additional Nics Errors</td></tr><tr class="Title"><td>Server Name</td><td>Error Detail</td>"
 
	Foreach ($errorItem in $errorReportinput)
	{
       Write-Output "<tr style='color:black'><td>$($errorItem.ServerName)</td><td>$($errorItem.AdditionalDiskNo)</td><td>$($errorItem.ErrorDetail)</td>"
	}
	Write-Output "</table>"
	if($sendEmailaddnic)
	{
	   Write-Output "</body></html>" 
	}
}
  
[array]$Report = "" | Select-Object ServerName,AdditionalNicNo,AdditionalNicVMNetwork,Result
[array]$errorReport = "" | Select-Object ServerName,AdditionalNicNo,ErrorDetail
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

$Networkcsv = $csvPath + "\Network.csv"
$constantscsv = $csvPath + "\Constants.csv"

$Networklist = Import-Csv $Networkcsv
$constantslist = Import-Csv $constantscsv

#$Networklist | Format-Table -AutoSize
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

foreach ($server in $Networklist)
{
   $Error.Clear()
   $result = ""
   #Add Additional Nics
   if ($server."Automation Status" -match "Active")
   {
      if ($server."Total New NIC Count" -gt 0)
      {
         $nicsAdded = 0
	  
	     #Get VM
	     $vm = Get-VM -Name $server.Name
	     if (!$?)
	     {
	        $result = "Error Finding VM"
	        $errorReportItem = "" | Select-Object ServerName,AdditionalNicNo,ErrorDetail
            $errorReportItem.ServerName = $server."Name"
		    $errorReportItem.AdditionalNicNo = "N/A"
	        $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
	        $errorReport = $errorReport + $errorReportItem
	        $Error.Clear()
		 
		    $ReportItem = "" | Select-Object ServerName,AdditionalNicNo,AdditionalNicVMNetwork,Result
	        $ReportItem.ServerName = $server."Name"
	        $ReportItem.AdditionalNicNo = "N/A"
		    $ReportItem.AdditionalNicVMNetwork = "N/A"
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
         }
	     else
	     {
	        while ($nicsAdded -lt $server."Total New NIC Count" )
	        {
     	        $nicsAdded = $nicsAdded + 1
	    	    Write-Host "Adding Additional Nic" $nicsAdded "to" $server.Name
			    $newVMNetwork = "New NIC" + $nicsAdded + " VMNetwork"
 		        $newNetworkAdapter = New-NetworkAdapter -VM $vm `
  			      -NetworkName $server.$newVMNetwork `
			      -StartConnected:$true `
			      -Confirm:$false
			   
		       if (!$?)
			   {
			      $result = "Error adding Nic"
	              $errorReportItem = "" | Select-Object ServerName,AdditionalNicNo,ErrorDetail
                  $errorReportItem.ServerName = $server."Name"
		          $errorReportItem.AdditionalNicNo = $nicsAdded
	              $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
	              $errorReport = $errorReport + $errorReportItem
	              $Error.Clear()
			   }
			   else
			   {
			      $result = "Success"
			   }
			
			   $ReportItem = "" | Select-Object ServerName,AdditionalNicNo,AdditionalNicVMNetwork,Result
	           $ReportItem.ServerName = $server."Name"
	           $ReportItem.AdditionalNicNo = $nicsAdded
		       $ReportItem.AdditionalNicVMNetwork = $server.$newVMNetwork
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
	        }
	   }
     }
   }
   else
   {
      if ($server."Total New NIC Count" -gt 0)
	  {
	     $result = "Automation Status Not Active"
		 $ReportItem = "" | Select-Object ServerName,AdditionalNicNo,AdditionalNicVMNetwork,Result
	     $ReportItem.ServerName = $server."Name"
	     $ReportItem.AdditionalNicNo = "N/A"
		 $ReportItem.AdditionalNicVMNetwork = "N/A"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem
      }
   }
}

Disconnect-VIServer * -Confirm:$false

$EmailReport = Generate-Report $Report $errorReport $sendEmailaddnic

if ($sendEmailaddnic)
{
   #WriteHTML to file
   $outpath = $csvPath + "\AddNics" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Add Additional Nics" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}