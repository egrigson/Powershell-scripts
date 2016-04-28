#input parameters
param([string] $csvPath,[string] $scriptSource,[Boolean] $sendEmailNetapp)

Write-Host "Beginning ConfigureNetapp.psl Script"

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

if ($sendEmailNetapp)
{
   $EmailReportNetapp = "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
   $EmailReportNetapp = $EmailReportNetapp + "<p>Results of Powershell Function ConfigureNetapp.ps1 run on $($date)"
}

$EmailReportNetapp = $EmailReportNetapp + (.$scriptSource\AddVol.ps1 $CSVPath $false)

$EmailReportNetapp = $EmailReportNetapp + (.$scriptSource\ConfigureVolOptions.ps1 $CSVPath $false)

$EmailReportNetapp = $EmailReportNetapp + (.$scriptSource\ConfigureExports.ps1 $CSVPath $false)

$EmailReportNetapp = $EmailReportNetapp + (.$scriptSource\MountVMNFS.ps1 $CSVPath $false)

if($sendEmailNetapp)
{  
   $EmailReportNetapp = $EmailReportNetapp + "</body></html>"
   
   #WriteHTML to file
   $outpath = $csvPath + "\configurenetapp" + $date + ".html"
   $EmailReportNetapp | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Configure Netapp Results" $EmailServer $EmailReportNetapp
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Output $EmailReportNetapp
}