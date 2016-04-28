#input parameters
param([string] $credentialPath)

$mflnetFile = $credentialPath + "\mflnet"
$mfltestFile = $credentialPath + "\mfltest"
#$mflsapFile = $credentialPath + "\mflsap"
$sysmanagerFle = $credentialPath + "\sysmanager"
$linuxRootFile = $credentialPath + "\linuxRoot"
$esxFile = $credentialPath + "\esx"


#Get Credentials


$mflnetcredential = $host.ui.PromptForCredential("Enter MFLNET credentials", "Please enter your mflnet Adm user name and password.", "", "")
$mfltestcredential = $host.ui.PromptForCredential("Enter MFLTEST credentials", "Please enter your mfltest Adm user name and password.", "", "")
#$mflsapcredential = $host.ui.PromptForCredential("Enter MFLSAP credentials", "Please enter your mflsap Adm user name and password.", "", "")
$sysmanagercredential = $host.ui.PromptForCredential("Enter sysmanager credentials", "Please enter sysmanager user name and password.", "sysmanager", "")
$linuxRootcredential = $host.ui.PromptForCredential("Enter linux root credentials", "Please enter linux user name and password.", "root", "")
$hostcredential = $host.ui.PromptForCredential("Enter esx root credentials", "Please enter esx root user name and password.", "root", "")

#Export Password to encrypted files
$mflnetcredential.Password | ConvertFrom-SecureString | Set-Content $mflnetFile
$mfltestcredential.Password | ConvertFrom-SecureString | Set-Content $mfltestFile
#$mflsapcredential.Password | ConvertFrom-SecureString | Set-Content $mflsapFile
$sysmanagercredential.Password | ConvertFrom-SecureString | Set-Content $sysmanagerFle
$linuxRootcredential.Password | ConvertFrom-SecureString | Set-Content $linuxRootFile
$hostcredential.Password | ConvertFrom-SecureString | Set-Content $esxFile
