#input parameters
param([string] $csvPath, [Boolean] $sendEmailconfNic)

Write-Host "Beginning ConfigureNics.psl Script"

#################Prepare Report######################################
$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

function Generate-Report {
param([array] $Reportinput,[array] $errorReportinput,[Boolean] $sendEmailconfNic)

	if ($sendEmailconfNic)
	{
	   Write-Output "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
	}
	Write-Output "<p>Results of Powershell Function $($csvPath)\ConfigureNics.ps1 run on $($date)"
	write-output "<table><tr class=""Title""><td colspan=""4"">Configure Nics Scripts</td></tr><tr class="Title"><td>Server</td><td>Script Run</td><td>Script Parameters</td><td>Script Result</td></tr>"
 
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
	if($sendEmailconfNic)
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

$Networkcsv = $csvPath + "\Network.csv"
$constantscsv = $csvPath + "\Constants.csv"

$Networklist = Import-Csv $Networkcsv
$constantslist = Import-Csv $constantscsv

#$Networklist | Format-Table -AutoSize
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
foreach ($server in $Networklist)
{
   if ($server."Automation Status" -match "Active")
   {
   
      #Set Bultin Nic Details for Win
      if ($server."OS Type" -match "Windows")
      {
         Write-Host "Configuring builtin Nic Network settings on" $server.Name
	     #Get VM
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
	        $builtinNICOldLabel = "Local Area Connection"
	        $builtinNICNewLabel = $server."Builtin NIC Label"
	        $builtinNICIP = $server."Builtin NIC IP"
	        $builtinNICSubnetMask = $server."Builtin NIC Subnet Mask"
	        $builtinNICDefaultGateway = $server."Builtin NIC Default Gateway"
	  
            $ScriptText = "`"C:\post install tasks\ConfigureNic.bat`" `"" + $builtinNICOldLabel + "`" `"" + $builtinNICNewLabel + "`" " + $builtinNICIP + " " + $builtinNICSubnetMask + " " + $builtinNICDefaultGateway
	  
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
	        }
		
		    $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	        $ReportItem.ServerName = $server.Name
		    $ReportItem.ScriptRun = "C:\post install tasks\ConfigureNic.bat"
	        $ReportItem.Parameters = $builtinNICOldLabel + "`" `"" + $builtinNICNewLabel + "`" " + $builtinNICIP + " " + $builtinNICSubnetMask + " " + $builtinNICDefaultGateway
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
	  
	        #Set DNS
	        $builtinNICDNS1 = $server."Builtin NIC DNS Server1"
	        $builtinNICDNS2 = $server."Builtin NIC DNS Server2"
            $ScriptText = "`"C:\post install tasks\ConfigureDNS.bat`" `"" + $builtinNICNewLabel + "`" " + $builtinNICDNS1 + " " + $builtinNICDNS2
	  
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
	        }
		
		    $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	        $ReportItem.ServerName = $server.Name
		    $ReportItem.ScriptRun = "C:\post install tasks\ConfigureDNS.bat"
	        $ReportItem.Parameters = $builtinNICNewLabel + "`" " + $builtinNICDNS1 + " " + $builtinNICDNS2
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
	      }
		  
	   }
	
	   #configure New Windows Nics
	   if ($server."Total New NIC Count" -gt 0 -and $server."OS Type" -match "Windows")
	   {
	      $nicsConfigured = 0
	   
	      #Get VM
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
	        while ($nicsConfigured -lt $server."Total New NIC Count" )
	        {
	           $nicsConfigured = $nicsConfigured + 1
		       Write-Host "Configuring Additional Nic" $nicsConfigured "Network settings on" $server.Name
			   $NICOldLabel = "Local Area Connection " + ($nicsConfigured + 1)
	           $NICNewLabel = "New Nic" + $nicsConfigured + " Label"
	           $NICIP = "New Nic" + $nicsConfigured + " IP"
	           $NICSubnetMask = "New Nic" + $nicsConfigured + " Subnet Mask"
		 
		       $ScriptText = "`"C:\post install tasks\ConfigureNic.bat`" `"" + $NICOldLabel + "`" `"" + $server.$NICNewLabel + "`" " + $server.$NICIP + " " + $server.$NICSubnetMask
		 
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
	           }
		
		       $ReportItem = "" | Select-Object ServerName,ScriptRun,Parameters,Result
	           $ReportItem.ServerName = $server.Name
		       $ReportItem.ScriptRun = "C:\post install tasks\ConfigureNic.bat"
	           $ReportItem.Parameters = $NICOldLabel + "`" `"" + $server.$NICNewLabel + "`" " + $server.$NICIP + " " + $server.$NICSubnetMask
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
		    }
	     }
      }
   
      #Set Builtin NIC for Linux
      if ($server."OS Type" -match "Linux")
      {
         Write-Host "Configuring builtin Nic Network settings on" $server.Name
	     #Get VM
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
	  
	        #Configure NIC
	        $builtinNICLabel = $server."Builtin NIC Label"
	        $builtinNICIP = $server."Builtin NIC IP"
	        $builtinNICSubnetMask = $server."Builtin NIC Subnet Mask"

            $ScriptText = "/root/scripts/configureNICs.sh " + $builtinNICLabel + " " + $builtinNICIP + " " + $builtinNICSubnetMask
	  
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
		    $ReportItem.ScriptRun = "/root/scripts/configureNICs.sh"
	        $ReportItem.Parameters = $builtinNICLabel + " " + $builtinNICIP + " " + $builtinNICSubnetMask
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
	
	        #Configure Gateway
	        $builtinNICDefaultGateway = $server."Builtin NIC Default Gateway"
			$fqdn = $server.Name + "." + $server."DNS Domain"
	  
	        $ScriptText = "/root/scripts/configureNetwork.sh " + $fqdn + " " + $builtinNICDefaultGateway
	  
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
		    $ReportItem.ScriptRun = "/root/scripts/configureNetwork.sh"
	        $ReportItem.Parameters = $server.Name + " " + $builtinNICDefaultGateway
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
	  
	        #Configure DNS and time
	        $builtinNICDNS1 = $server."Builtin NIC DNS Server1"
	        $builtinNICDNS2 = $server."Builtin NIC DNS Server2"
 
            $ScriptText = "/root/scripts/configureDNS.sh " + $builtinNICDNS1 + " " + $builtinNICDNS2 + " " + $server."DNS Domain"

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
		    $ReportItem.ScriptRun = "/root/scripts/configureDNS.sh"
	        $ReportItem.Parameters = $builtinNICDNS1 + " " + $builtinNICDNS2
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
			
			switch ($builtinNICDNS1)
			{
			   "10.7.22.150" {$secondaryNTP = "10.7.22.151"}
			   "10.1.108.150" {$secondaryNTP = "10.1.108.60"}
			   "10.1.100.150" {$secondaryNTP = "10.1.100.50"}
			   default {$secondaryNTP = "10.1.108.60"}
			}
			
		 
		 
	        $ScriptText = "/root/scripts/configureNTP.sh " + $builtinNICDNS1 + " " + $secondaryNTP

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
		    $ReportItem.ScriptRun = "/root/scripts/configureNTP.sh"
	        $ReportItem.Parameters = $builtinNICDNS1 + " " + $builtinNICDNS2
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
			
			#Configure Hosts File
	        $dnsIPAddress = $server."Builtin NIC IP"
			$dnsDomain = $server."DNS Domain"
 	  
            $ScriptText = "/root/scripts/configureHosts.sh " + $dnsIPAddress + " " + $server."Name" + " " + $dnsDomain

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
		    $ReportItem.ScriptRun = "/root/scripts/configureDNS.sh"
	        $ReportItem.Parameters = $builtinNICDNS1 + " " + $builtinNICDNS2
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
			
			switch ($builtinNICDNS1)
			{
			   "10.7.22.150" {$secondaryNTP = "10.7.22.151"}
			   "10.1.108.150" {$secondaryNTP = "10.1.108.60"}
			   "10.1.100.150" {$secondaryNTP = "10.1.100.50"}
			   default {$secondaryNTP = "10.1.108.60"}
			}
			
		 
		 
	        $ScriptText = "/root/scripts/configureNTP.sh " + $builtinNICDNS1 + " " + $secondaryNTP

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
		    $ReportItem.ScriptRun = "/root/scripts/configureNTP.sh"
	        $ReportItem.Parameters = $builtinNICDNS1 + " " + $builtinNICDNS2
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
	     }

      }
   
      #Set new Linux NICs
      if ($server."Total New NIC Count" -gt 0 -and $server."OS Type" -match "Linux")
	   {
	      $nicsConfigured = 0
	   
	      #Get VM
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
	  
	        while ($nicsConfigured -lt $server."Total New NIC Count" )
	        {
	           $nicsConfigured = $nicsConfigured + 1
	           Write-Host "Configuring Additional Nic" $nicsConfigured "Network settings on" $server.Name
			   $NICLabel = "New Nic" + $nicsConfigured + " Label"
	           $NICIP = "New Nic" + $nicsConfigured + " IP"
	           $NICSubnetMask = "New Nic" + $nicsConfigured + " Subnet Mask"
		 
               $ScriptText = "/root/scripts/configureNICs.sh " + $server.$NICLabel + " " + $server.$NICIP + " " + $server.$NICSubnetMask
		 
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
		       $ReportItem.ScriptRun = "/root/scripts/configureNICs.sh"
	           $ReportItem.Parameters = $server.$NICLabel + " " + $server.$NICIP + " " + $server.$NICSubnetMask
	           $ReportItem.Result = $result
	           $Report = $Report + $ReportItem
		    }
	     }
      }
   
      #Restart Linux Network service
      if ($server."OS Type" -match "Linux")
      {
         $ScriptText = "/root/scripts/restartNetwork.sh"
	  
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
	        $ReportItem.ScriptRun = "/root/scripts/restartNetwork.sh"
	        $ReportItem.Parameters = "None"
	        $ReportItem.Result = $result
	        $Report = $Report + $ReportItem
	  }
   }
   else
   {
      if ($server."OS Type" -match "Windows" -or $server."OS Type" -match "Linux")
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
Disconnect-VIServer * -Confirm:$false | Out-Null

$EmailReport = Generate-Report $Report $errorReport $sendEmailconfNic

if($sendEmailconfNic)
{
   #WriteHTML to file
   $outpath = $csvPath + "\ConfigureNICs" + $date + ".html"
   $EmailReport | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Configure Nics" $EmailServer $EmailReport
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Host "Script Completed"
   Write-Output $EmailReport
}
	  
