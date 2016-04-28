#input parameters
param([string] $csvPath,[string] $scriptSource,[Boolean] $sendEmailaddhardware)

Write-Host "Beginning AddAdditionalHardware.psl Script"

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

if($sendEmailaddhardware)
{
   $EmailReporthardware = "<html><head><title></title><style type=""text/css"">.Error {color:#FF0000;font-weight: bold;}.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}.Normal {}</style></head><body>"
   $EmailReporthardware = $EmailReporthardware + "<p>Results of Powershell Function AddAdditionalHardware.ps1 run on $($date)"
}

$EmailReporthardware = $EmailReporthardware + (.$scriptSource\AddPageFile.ps1 $CSVPath $false)

$EmailReporthardware = $EmailReporthardware + (.$scriptSource\AddDisks.ps1 $CSVPath $false)

#$EmailReporthardware = $EmailReporthardware + {. $csvPath\AddClones.ps1 $CSVPath $false}

$EmailReporthardware = $EmailReporthardware + (.$scriptSource\AddNics.ps1 $CSVPath $false)


if($sendEmailaddhardware)
{
   $EmailReporthardware = $EmailReporthardware + "</body></html>"
   
   #WriteHTML to file
   $outpath = $csvPath + "\AddAdditionalHardware" + $date + ".html"
   $EmailReporthardware | Out-File -FilePath $outpath
   
   send-SMTPmail $EmailTo $EmailFrom "Add Additional Hardware" $EmailServer $EmailReporthardware
   
   Write-Host "Script Completed, Email Sent - Press any key to close window"
   $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
   Write-Output $EmailReporthardware
}
