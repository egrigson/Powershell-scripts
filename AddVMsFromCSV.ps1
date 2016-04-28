#input parameters
param([string] $csvPath,[Boolean] $sendEmailAddVMs)

Write-Host "Beginning AddVMsFromCSV.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailAddVMs)

	if ($sendEmailAddVMs)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}   
	Write-Output "<p>Results of Powershell Function AddVMsFromCSV run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""5"">ADD VMs From CSV Results</td></tr><tr class="Title"><td>Server Name</td><td>Host Name</td><td>VM Folder</td><td>VM Network</td><td>Script Result</td></tr>"
 
	Foreach ($ReportItem in $Reportinput)
	{
	   if ($ReportItem.Result -match "Success") 
	   {   
	      Write-Output "<tr style='color:green'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.Host)</td><td>$($ReportItem.Folder)</td><td>$($ReportItem.Network)</td><td>$($ReportItem.Result)</td></tr> "
	   } 
	   else 
	   {
          Write-Output "<tr style='color:red'><td>$($ReportItem.ServerName)</td><td>$($ReportItem.Host)</td><td>$($ReportItem.Folder)</td><td>$($ReportItem.Network)</td><td>$($ReportItem.Result)</td></tr> "
	   }
	}
	Write-Output "</table><br>"
	write-output "<table><tr class=""Title""><td colspan=""2"">ADD VMs From CSV Errors</td></tr><tr class="Title"><td>Server Name</td><td>Error Detail</td>"
 
    Foreach ($errorItem in $errorReportinput)
	{
         Write-Output "<tr style='color:black'><td>$($errorItem.ServerName)</td><td>$($errorItem.ErrorDetail)</td>"
	}
	Write-Output "</table>"
	if($sendEmailAddVMs)
	{
	    Write-Output "</body></html>" 
	}
}
  
[array]$Report = "" | Select-Object ServerName,Host,Folder,Network,Result
[array]$errorReport = "" | Select-Object ServerName,ErrorDetail
#################End Prepare Report######################################



#################Start of Functions######################################

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

function Send-SMTPmail($to, $from, $subject, $smtpserver, $body) {
	$mailer = new-object Net.Mail.SMTPclient($smtpserver)
	$msg = new-object Net.Mail.MailMessage($from,$to,$subject,$body)
	$msg.IsBodyHTML = $true
	$mailer.send($msg)
}



#################END of Functions######################################
#######################################################################
#######################################################################
#######################################################################
#######################################################################
#######################################################################
#######################################################################
#######################################################################
#######################################################################
#################Start of Main Code####################################

$servercsv = $csvPath + "\Servers.csv"
$constantscsv = $csvPath + "\Constants.csv"

$serverlist = Import-Csv $servercsv
$constantslist = Import-Csv $constantscsv

#$serverlist | Format-Table -Autosize

#$constantslist | Format-Table -AutoSize
  
#Get Constants
$vcServer = FindConstant $constantslist "VirtualCentre"
$mflnetUserName = FindConstant $constantslist "MFLNET username"
$EmailTo = FindConstant $constantslist "Email To"
$EmailFrom = FindConstant $constantslist "Email From"
$EmailServer = FindConstant $constantslist "Email Server"

#Set Credentials
$mflnetcredentialFile = $csvPath + "\mflnet"
$mflnetPassword = Get-Content $mflnetcredentialFile | ConvertTo-SecureString
$mflnetcredential = New-Object System.Management.Automation.PsCredential `
   $mflnetUserName,$mflnetPassword
	

	
#connect Virtual Centre
Connect-VIServer $vcServer -Credential $mflnetcredential  | Out-Null

$csmSpecMgr = Get-View 'CustomizationSpecManager'


foreach ($server in $serverlist) 
{ 
   $Error.Clear()
   $result = ""
   if ($server."Automation Status" -match "Active")
   {

	if ($server."Type" -match "Virtual" )
	{

	   Write-Host "Creating VM" $server.Name "on" $server."Starting Host"
	   #Prepare OSCustomizationSpec
	   
	   
	   $OSSpecName = $server."Template Customization To Duplicate"
		
	   $newOSSpecName = $OSSpecName + $server.Name

       $csmSpecMgr.DuplicateCustomizationSpec($OSSpecName ,$newOSSpecName)
	
   	   
	   
										   
	   $newOSSpec = Get-OSCustomizationSpec -Name $newOSSpecName
	   #set Server Name
	   
	   Set-OSCustomizationSpec -Spec $newOSSpec -NamingScheme "Fixed" -NamingPrefix $server.Name -ErrorVariable $specError | Out-Null
	   
	   if (!$?)
	   {
	      $result = "Error with Specification"
		  $errorReportItem = "" | Select-Object ServerName,ErrorDetail
		  $errorReportItem.ServerName = $server.Name
		  $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		  $errorReport = $errorReport + $errorReportItem
		  $Error.Clear()
	   }
	   
	   # ** Clone new VM
	
	 #  sleep 5
	   $vmFolder = Get-Datacenter $server.Datacentre | Get-Folder  $server."VM Folder"
	   #$templateFolder = Get-Datacenter $server.Datacentre | Get-Folder $server.Template
	   
	   $vmDatastore = Get-Datastore -Name $server."System Datastore" -Datacenter $server.Datacentre
	   #$vmTemplate = Get-Template -Name $server.Template -Location $templateFolder
       New-VM -Confirm:$false `
		   -Name ($server.Name).ToLower() `
           -Template $server.Template `
		   -DiskStorageFormat Thin `
           -Description $server.Notes `
           -VMHost $server."Starting Host" `
           -Datastore $vmDatastore `
		   -Location $vmFolder `
		   -OSCustomizationSpec $newOSSpec | Out-Null
		if (!$?)
		{
		   $result = $result + "Problem creating VM"
		   $errorReportItem = "" | Select-Object ServerName,ErrorDetail
		   $errorReportItem.ServerName = $server.Name
		   $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		   $errorReport = $errorReport + $errorReportItem
		   $Error.Clear()
		}
		else
		{
	       Set-VM -Confirm:$false `
		      -VM $server.Name `
              -NumCpu $server."CPU Count" `
              -MemoryMB ([int]$server."Memory Size - MB") | Out-Null
		
		   if(!$?)
		   {
		      $result = $result + "Problem Setting VM Parameters"
		      $errorReportItem = "" | Select-Object ServerName,ErrorDetail
		      $errorReportItem.ServerName = $server.Name
		      $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		      $errorReport = $errorReport + $errorReportItem
		      $Error.Clear()
		   }
		   else
		   {
	          Get-NetworkAdapter -VM $server.Name | Set-NetworkAdapter -NetworkName $server."NIC1 VMNetwork" -StartConnected $true -Confirm:$false | Out-Null
			  
			  if(!$?)
			  {
			     $result = $result + "Problem Setting Network Card"
		         $errorReportItem = "" | Select-Object ServerName,ErrorDetail
		         $errorReportItem.ServerName = $server.Name
		         $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		         $errorReport = $errorReport + $errorReportItem
		         $Error.Clear()
			  }
			  else
			  {
	             Start-VM -VM $server.Name -Confirm:$false | Out-Null
				 
				 if(!$?)
			     {
			        $result = $result + "Problem Starting VM"
		            $errorReportItem = "" | Select-Object ServerName,ErrorDetail
		            $errorReportItem.ServerName = $server.Name
		            $errorReportItem.ErrorDetail = $error[0].ToString() + $error[0].InvocationInfo.PositionMessage
		            $errorReport = $errorReport + $errorReportItem
		            $Error.Clear()
			     }
				 else
	             {
	                $result = "Success"
				 }
			  }
			}
        }	   
	   #Remove CustomisationSpec
	   Remove-OSCustomizationSpec -CustomizationSpec $newOSSpecName -Confirm:$false | Out-Null
	   
	   $ReportItem = "" | Select-Object ServerName,Host,Folder,Network,Result
	   $ReportItem.ServerName = $server.Name
	   $ReportItem.Host = $server."Starting Host"
	   $ReportItem.Folder = $server."VM Folder"
	   $ReportItem.Network = $server."NIC1 VMNetwork"
	   $ReportItem.Result = $result
	   $Report = $Report + $ReportItem
      
	  }
   }
   else
   {
      if ($server."Type" -match "Virtual")
	  {
	     $result = "Automation Status Not Active"
	     $ReportItem = "" | Select-Object ServerName,Host,Folder,Network,Result
	     $ReportItem.ServerName = $server.Name
	     $ReportItem.Host = "N/A"
	     $ReportItem.Folder = "N/A"
	     $ReportItem.Network = "N/A"
	     $ReportItem.Result = $result
	     $Report = $Report + $ReportItem
	   }
	}
}


#Restart VMs after sleep
Write-Host "Sleeping for 10mins to ensure all new VMs are started"
sleep 600

foreach ($server in $Report) 
{
   if ($server."Result" -match "Success")
   {
      $vm = Get-VM -Name $server.ServerName
	  if ($vm.PowerState -match "PoweredOn")
	  {
         Write-Host "Restarting" $server.ServerName
		 Restart-VMGuest -VM $vm -Confirm:$false | Out-Null
	  }
   }
}
   
#shutdown VMs after sleep
Write-Host "Sleeping for 5mins to ensure all new VMs have restarted"
sleep 300
foreach ($server in $Report) 
{
   if ($server."Result" -match "Success")
   {
      $vm = Get-VM -Name $server.ServerName
	  if ($vm.PowerState -match "PoweredOn")
	  {
         Write-Host "Shutting down" $server.ServerName
		 Shutdown-VMGuest -VM $vm -Confirm:$false | Out-Null
	  }
   }
}

Write-Host "Sleeping for 2:30mins to ensure all new VMs have shutdown"
sleep 150
foreach ($server in $Report) 
{
   if ($server."Result" -match "Success")
   {
      $vm = Get-VM -Name $server.ServerName
	  if ($vm.PowerState -match "PoweredOn")
	  {
         Write-Host "Powering off" $server.ServerName
		 Stop-VM -VM $vm -Confirm:$false | Out-Null
	  }
   }
}

Disconnect-VIServer * -Confirm:$false

$EmailReport = Generate-Report $Report $errorReport $sendEmailAddVMs

if ($sendEmailAddVMs)
{
   #WriteHTML to file
   $outpath = $csvPath + "\AddVMsFromCSV" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "AddVMsFromCSV Report" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}