#This script generates a list of the possible VMware PowerCLI commands, which can then be cut and pasted to the Wordpress syntax plugin
#For instructions please see http://www.vexperienced.co.uk/2012/02/20/adding-a-custom-powercli-brush-for-syntax-highlighting-on-wordpress/

﻿Connect-VIServer <your-vCenter-server> -WarningAction Continue

# choose 'Cmdlet' or 'Alias' to query with
$typetoUpdate = "Cmdlet"
#$typetoUpdate = "Alias"
$outputFile = "c:\test.txt"

$allcmds = Get-Command -Module vmware* -CommandType $typetoUpdate
$lastLine = $false

if ($typetoUpdate = "Cmdlet") {
	$Output = "var keywords = "
	$itemsPerLine = 5
} else {
	$Output = "var alias = "
	$itemsPerLine = 10
}

for($currentcmd = 0; $currentcmd -lt $allcmds.Length; $currentcmd += $itemsPerLine) {

    # calculate the end index for this iteration
    $endindex = $currentcmd + ($itemsPerLine - 1)
    if ($endindex -ge $allcmds.Length) {
        $endindex = $allcmds.Length - 1
		$lastLine = $true
    }

	#insert a leading apostrophe at the start of each line
	$Output += "'"
	#insert each cmdlet Name
	foreach($cmd in $allcmds[$currentcmd..$endindex]) {
        $Output += $cmd.Name + " "
    }
    # add a traling apostrophe at the end of each line
	$Output += "'"
	# format line endings
	if (!($lastLine)) {
		$Output += " + "
	} else {
		$Output += ";"
	}
	$output += [Environment]::NewLine
} 
$output | Out-File -FilePath $outputFile
