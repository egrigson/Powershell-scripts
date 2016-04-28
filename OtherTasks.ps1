#input parameters
param([string] $csvPath,[string] $scriptSource,[Boolean] $sendEmailOtherTasks)

Write-Host "Beginning OtherTasks.psl Script"

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

if($sendEmailOtherTasks)
{
   $EmailReportOtherTasks = "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
   $EmailReportOtherTasks = $EmailReportOtherTasks + "<p>Results of Powershell Function OtherTasks.ps1 run on $($date)"
}

#$EmailReportOtherTasks = $EmailReportOtherTasks + (.$scriptSource\InstallAgents.ps1 $CSVPath $false)

$EmailReportOtherTasks = $EmailReportOtherTasks + (.$scriptSource\Setbootini.ps1 $CSVPath $false)

$EmailReportOtherTasks = $EmailReportOtherTasks + (.$scriptSource\ConfigureDNS.ps1 $CSVPath $false)


if($sendEmailOtherTasks)
{
   $EmailReportOtherTasks = $EmailReportOtherTasks + "</body></html>"
   
   #WriteHTML to file
   $outpath = $csvPath + "\OtherTasks" + $date + ".html"
   $EmailReportOtherTasks | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Other Tasks" $EmailServer $EmailReportOtherTasks
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Output $EmailReportOtherTasks
}
