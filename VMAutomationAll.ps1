#input parameters
param([string] $csvPath, [string]$scriptSource)

Write-Host "Beginning Script VMAutomationAll.psl"

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

#Get Credentials
(.$scriptSource\ResetCredentials.ps1 $csvPath)


$EmailReportvmAuto = "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
$EmailReportvmAuto = $EmailReportvmAuto + "<p>Results of Powershell Function VMAutomationAll.ps1 run on $($date)"

$EmailReportvmAuto = $EmailReportvmAuto + (.$scriptSource\ConfigureNetapp.ps1 $CSVPath $scriptSource $false)

$EmailReportvmAuto = $EmailReportvmAuto + (.$scriptSource\AddVMsFromCSV.ps1 $CSVPath $false)

$EmailReportvmAuto = $EmailReportvmAuto + (.$scriptSource\AddAdditionalhardware.ps1 $CSVPath $scriptSource $false)

$EmailReportvmAuto = $EmailReportvmAuto + (.$scriptSource\GuestConfig.ps1 $CSVPath $scriptSource $false)

$outpath = $csvPath + "\VMAutomationAll" + $date + ".html"
$EmailReportvmAuto| Out-File -FilePath $outpath


$EmailReportvmAuto = $EmailReportvmAuto + "</body></html>"
send-SMTPmail $EmailTo $EmailFrom "VM Automation All Operations" $EmailServer $EmailReportvmAuto

Write-Host "Script Completed, Email Sent - Press any key to close window"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
