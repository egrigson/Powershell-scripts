#input parameters
param([string] $csvPath,[string] $scriptSource,[Boolean] $sendEmailGuest)

Write-Host "Beginning GuestConfig.psl Script"

$date = Get-Date -Format "dd-MM-yyyy-hh-mm"

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

$constantscsv = $csvPath + "\Constants.csv"
$constantslist = Import-Csv $constantscsv
$EmailTo = FindConstant $constantslist "Email To"
$EmailFrom = FindConstant $constantslist "Email From"
$EmailServer = FindConstant $constantslist "Email Server"

if ($sendEmailGuest)
{
   $EmailReportguest = "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
   $EmailReportguest = $EmailReportguest + "<p>Results of Powershell Function GuestConfigs.ps1 run on $($date)"
}

.$scriptSource\PowerOnVMs.ps1 $csvPath
Write-Host "Sleeping for 5mins to Ensure all VMs are fully started"
sleep 300

$EmailReportguest = $EmailReportguest + (.$scriptSource\ConfigureCDDrive.ps1 $CSVPath $false)

$EmailReportguest = $EmailReportguest + (.$scriptSource\ConfigurePageFile.ps1 $CSVPath $false)

$EmailReportguest = $EmailReportguest + (.$scriptSource\ConfigureDisks.ps1 $CSVPath $false)

#$EmailReportguest = $EmailReportguest + (.$csvPath\ConfigureClones.ps1 $CSVPath $false)

$EmailReportguest = $EmailReportguest + (.$scriptSource\ConfigureNICs.ps1 $CSVPath $false)

$EmailReportguest = $EmailReportguest +  (.$scriptSource\JoinMachinesToDomain.ps1 $CSVPath $false)

$EmailReportguest = $EmailReportguest +  (.$scriptSource\ConfigureFSTAB.ps1 $CSVPath $false)

Write-Host "Sleeping for 2mins to Ensure all VMs are started"
sleep 120

$EmailReportguest = $EmailReportguest +  (.$scriptSource\OtherTasks.ps1 $CSVPath .$scriptSource $false)

if($sendEmailGuest)
{
   #WriteHTML to file
   $outpath = $csvPath + "\GuestConfig" + $date + ".html"
   $EmailReporthardware | Out-File -FilePath $outpath
   
   $EmailReportguest = $EmailReportguest + "</body></html>"
   send-SMTPmail $EmailTo $EmailFrom "Configure Guest" $EmailServer $EmailReportguest
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Output $EmailReportguest
}



