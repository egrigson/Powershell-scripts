/**
 * SyntaxHighlighter
 * http://alexgorbatchev.com/SyntaxHighlighter
 *
 * SyntaxHighlighter is donationware. If you are using it, please donate.
 * http://alexgorbatchev.com/SyntaxHighlighter/donate.html
 *
 * @version
 * 3.0.83 (July 02 2010)
 * 
 * @copyright
 * Copyright (C) 2004-2010 Alex Gorbatchev.
 *
 * @license
 * Dual licensed under the MIT and GPL licenses.
 * ------------------------------------------------------
 * PowerCLI brush created by Ed Grigson Jan 12th 2012
 * http://www.vExperienced.co.uk
 * ------------------------------------------------------
 */
SyntaxHighlighter.brushes.PowerCLI = function()
{
		var keywords = 'Add-Content Add-History Add-Member Add-PSSnapin Clear(-Content)? Clear-Item ' +
					'Clear-ItemProperty Clear-Variable Compare-Object ConvertFrom-SecureString Convert-Path ' +
					'ConvertTo-Html ConvertTo-SecureString Copy(-Item)? Copy-ItemProperty Export-Alias ' +
					'Export-Clixml Export-Console Export-Csv ForEach(-Object)? Format-Custom Format-List ' +
					'Format-Table Format-Wide Get-Acl Get-Alias Get-AuthenticodeSignature Get-ChildItem Get-Command ' +
					'Get-Content Get-Credential Get-Culture Get-Date Get-EventLog Get-ExecutionPolicy ' +
					'Get-Help Get-History Get-Host Get-Item Get-ItemProperty Get-Location Get-Member ' +
					'Get-PfxCertificate Get-Process Get-PSDrive Get-PSProvider Get-PSSnapin Get-Service ' +
					'Get-TraceSource Get-UICulture Get-Unique Get-Variable Get-WmiObject Group-Object ' +
					'Import-Alias Import-Clixml Import-Csv Invoke-Expression Invoke-History Invoke-Item ' +
					'Join-Path Measure-Command Measure-Object Move(-Item)? Move-ItemProperty New-Alias ' +
					'New-Item New-ItemProperty New-Object New-PSDrive New-Service New-TimeSpan ' +
					'New-Variable Out-Default Out-File Out-Host Out-Null Out-Printer Out-String Pop-Location ' +
					'Push-Location Read-Host Remove-Item Remove-ItemProperty Remove-PSDrive Remove-PSSnapin ' +
					'Remove-Variable Rename-Item Rename-ItemProperty Resolve-Path Restart-Service Resume-Service ' +
					'Select-Object Select-String Set-Acl Set-Alias Set-AuthenticodeSignature Set-Content ' +
					'Set-Date Set-ExecutionPolicy Set-Item Set-ItemProperty Set-Location Set-PSDebug ' +
					'Set-Service Set-TraceSource Set(-Variable)? Sort-Object Split-Path Start-Service ' +
					'Start-Sleep Start-Transcript Stop-Process Stop-Service Stop-Transcript Suspend-Service ' +
					'Tee-Object Test-Path Trace-Command Update-FormatData Update-TypeData Where(-Object)? ' +
					'Write-Debug Write-Error Write(-Host)? Write-Output Write-Progress Write-Verbose Write-Warning';


		keywords += ' Add-DeployRule Add-EsxSoftwareDepot Add-EsxSoftwarePackage Add-PassthroughDevice Add-VMHost ' +
					'Add-VmHostNtpServer Apply-DrsRecommendation Apply-ESXImageProfile Apply-VMHostProfile Attach-Baseline ' +
					'Compare-EsxImageProfile Connect-VIServer Copy-DatastoreItem Copy-DeployRule Copy-HardDisk ' +
					'Copy-VMGuestFile Detach-Baseline Disconnect-VIServer Dismount-Tools Download-Patch ' + 
					'Export-EsxImageProfile Export-VApp Export-VMHostProfile Format-VMHostDiskPartition Get-AdvancedSetting ' + 
					'Get-AlarmAction Get-AlarmActionTrigger Get-AlarmDefinition Get-Annotation Get-Baseline ' + 
					'Get-CDDrive Get-Cluster Get-Compliance Get-CustomAttribute Get-Datacenter ' + 
					'Get-Datastore Get-DatastoreCluster Get-DeployRule Get-DeployRuleSet Get-DrsRecommendation ' + 
					'Get-DrsRule Get-ErrorReport Get-EsxCli Get-EsxImageProfile Get-EsxSoftwareChannel ' + 
					'Get-EsxSoftwarePackage Get-EsxTop Get-FloppyDrive Get-Folder Get-HAPrimaryVMHost ' + 
					'Get-HardDisk Get-Inventory Get-IScsiHbaTarget Get-LicenseDataManager Get-Log ' + 
					'Get-LogType Get-NetworkAdapter Get-NicTeamingPolicy Get-OSCustomizationNicMapping Get-OSCustomizationSpec ' + 
					'Get-PassthroughDevice Get-Patch Get-PatchBaseline Get-PowerCLIConfiguration Get-PowerCLIVersion ' + 
					'Get-ResourcePool Get-ScsiController Get-ScsiLun Get-ScsiLunPath Get-Snapshot ' + 
					'Get-Stat Get-StatInterval Get-StatType Get-Task Get-Template ' + 
					'Get-UsbDevice Get-VApp Get-VIAccount Get-VICredentialStoreItem Get-VIEvent ' + 
					'Get-View Get-VIObjectByVIView Get-VIPermission Get-VIPrivilege Get-VIProperty ' + 
					'Get-VIRole Get-VirtualPortGroup Get-VirtualSwitch Get-VM Get-VMGuest ' + 
					'Get-VMGuestNetworkInterface Get-VMGuestRoute Get-VMHost Get-VMHostAccount Get-VMHostAdvancedConfiguration ' + 
					'Get-VMHostAttributes Get-VMHostAuthentication Get-VMHostAvailableTimeZone Get-VMHostDiagnosticPartition Get-VMHostDisk ' + 
					'Get-VMHostDiskPartition Get-VMHostFirewallDefaultPolicy Get-VMHostFirewallException Get-VMHostFirmware Get-VMHostHba ' + 
					'Get-VMHostImageProfile Get-VMHostMatchingRules Get-VMHostModule Get-VMHostNetwork Get-VMHostNetworkAdapter ' + 
					'Get-VMHostNtpServer Get-VMHostPatch Get-VMHostProfile Get-VMHostProfileRequiredInput Get-VMHostRoute ' + 
					'Get-VMHostService Get-VMHostSnmp Get-VMHostStartPolicy Get-VMHostStorage Get-VMHostSysLogServer ' + 
					'Get-VMQuestion Get-VMResourceConfiguration Get-VMStartPolicy Import-VApp Import-VMHostProfile ' + 
					'Install-VMHostPatch Invoke-VMScript Mount-Tools Move-Cluster Move-Datacenter ' + 
					'Move-Folder Move-Inventory Move-ResourcePool Move-Template Move-VApp ' + 
					'Move-VM Move-VMHost New-AdvancedSetting New-AlarmAction New-AlarmActionTrigger ' + 
					'New-CDDrive New-Cluster New-CustomAttribute New-CustomField New-Datacenter ' + 
					'New-Datastore New-DeployRule New-DrsRule New-EsxImageProfile New-FloppyDrive ' + 
					'New-Folder New-HardDisk New-IScsiHbaTarget New-NetworkAdapter New-OSCustomizationNicMapping ' + 
					'New-OSCustomizationSpec New-PatchBaseline New-ResourcePool New-ScsiController New-Snapshot ' + 
					'New-StatInterval New-Template New-VApp New-VICredentialStoreItem New-VIPermission ' + 
					'New-VIProperty New-VIRole New-VirtualPortGroup New-VirtualSwitch New-VM ' + 
					'New-VMGuestRoute New-VMHostAccount New-VMHostNetworkAdapter New-VMHostProfile New-VMHostRoute ' + 
					'Remediate-Inventory Remove-AdvancedSetting Remove-AlarmAction Remove-AlarmActionTrigger Remove-Baseline ' + 
					'Remove-CDDrive Remove-Cluster Remove-CustomAttribute Remove-CustomField Remove-Datacenter ' + 
					'Remove-Datastore Remove-DeployRule Remove-DrsRule Remove-EsxSoftwareDepot Remove-EsxSoftwarePackage ' + 
					'Remove-FloppyDrive Remove-Folder Remove-HardDisk Remove-Inventory Remove-IScsiHbaTarget ' + 
					'Remove-NetworkAdapter Remove-OSCustomizationNicMapping Remove-OSCustomizationSpec Remove-PassthroughDevice Remove-ResourcePool ' + 
					'Remove-Snapshot Remove-StatInterval Remove-Template Remove-UsbDevice Remove-VApp ' + 
					'Remove-VICredentialStoreItem Remove-VIPermission Remove-VIProperty Remove-VIRole Remove-VirtualPortGroup ' + 
					'Remove-VirtualSwitch Remove-VM Remove-VMGuestRoute Remove-VMHost Remove-VMHostAccount ' + 
					'Remove-VMHostNetworkAdapter Remove-VMHostNtpServer Remove-VMHostProfile Remove-VMHostRoute Repair-DeployImageCache ' + 
					'Repair-DeployRuleSetCompliance Restart-VM Restart-VMGuest Restart-VMHost Restart-VMHostService ' + 
					'Scan-Inventory Set-AdvancedSetting Set-AlarmDefinition Set-Annotation Set-CDDrive ' + 
					'Set-Cluster Set-CustomAttribute Set-CustomField Set-Datacenter Set-Datastore ' + 
					'Set-DeployRule Set-DeployRuleSet Set-DrsRule Set-EsxImageProfile Set-FloppyDrive ' + 
					'Set-Folder Set-HardDisk Set-IScsiHbaTarget Set-NetworkAdapter Set-NicTeamingPolicy ' + 
					'Set-OSCustomizationNicMapping Set-OSCustomizationSpec Set-PatchBaseline Set-PowerCLIConfiguration Set-ResourcePool ' + 
					'Set-ScsiController Set-ScsiLun Set-ScsiLunPath Set-Snapshot Set-StatInterval ' + 
					'Set-Template Set-VApp Set-VIPermission Set-VIRole Set-VirtualPortGroup ' + 
					'Set-VirtualSwitch Set-VM Set-VMGuestNetworkInterface Set-VMHost Set-VMHostAccount ' + 
					'Set-VMHostAdvancedConfiguration Set-VMHostAuthentication Set-VMHostDiagnosticPartition Set-VMHostFirewallDefaultPolicy Set-VMHostFirewallException ' + 
					'Set-VMHostFirmware Set-VMHostHba Set-VMHostModule Set-VMHostNetwork Set-VMHostNetworkAdapter ' + 
					'Set-VMHostProfile Set-VMHostRoute Set-VMHostService Set-VMHostSnmp Set-VMHostStartPolicy ' + 
					'Set-VMHostStorage Set-VMHostSysLogServer Set-VMQuestion Set-VMResourceConfiguration Set-VMStartPolicy ' + 
					'Shutdown-VMGuest Stage-Patch Start-VApp Start-VM Start-VMHost ' + 
					'Start-VMHostService Stop-Task Stop-VApp Stop-VM Stop-VMHost ' + 
					'Stop-VMHostService Suspend-VM Suspend-VMGuest Suspend-VMHost Switch-ActiveDeployRuleSet ' + 
					'Test-DeployRuleSetCompliance Test-VMHostProfileCompliance Test-VMHostSnmp Update-Tools Wait-Task ' + 
					'Wait-Tools ';



	var alias = 'ac Answer-VMQuestion asnp cat cd chdir clc clear clhy cli ' +
				' clp cls clv compare copy cp cpi cpp cvpa dbp del diff ' +
				' dir ebp echo epal epcsv epsn erase etsn exsn fc fl foreach ' +
				' ft fw gal gbp gc gci gcm gcs gdr Get-ESX Get-PowerCLIDocumentation Get-VC ' +
				' Get-VIServer Get-VIToolkitConfiguration Get-VIToolkitVersion ghy gi gjb gl gm gmo gp gps group ' +
				' gsn gsnp gsv gu gv gwmi h history icm iex ihy ii ' +
				' ipal ipcsv ipmo ipsn ise iwmi kill lp ls man md measure ' +
				' mi mount move mp mv nal ndr ni nmo nsn nv ogv ' +
				' oh popd ps pushd pwd r rbp rcjb rd rdr ren ri ' +
				' rjb rm rmdir rmo rni rnp rp rsn rsnp rv rvpa rwmi ' +
				' sajb sal saps sasv sbp sc select set Set-VIToolkitConfiguration si sl sleep ' +
				' sort sp spjb spps spsv start sv swmi tee type where wjb ' +
				' write  % \\? ';

	this.regexList = [

		{ regex: /#.*$/gm,										css: 'comments' },  // one line comments

		{ regex: /\$[a-zA-Z0-9]+\b/g,							css: 'value'   },   // variables $Computer1

		{ regex: /\-[a-zA-Z]+\b/g,								css: 'keyword' },   // Operators    -not  -and  -eq

		{ regex: SyntaxHighlighter.regexLib.doubleQuotedString,	css: 'string' },    // strings

		{ regex: SyntaxHighlighter.regexLib.singleQuotedString,	css: 'string' },    // strings

		{ regex: new RegExp(this.getKeywords(keywords), 'gmi'),	css: 'keyword' },

		{ regex: new RegExp(this.getKeywords(alias), 'gmi'),	css: 'keyword' }

	];

};

SyntaxHighlighter.brushes.PowerCLI.prototype = new SyntaxHighlighter.Highlighter();
SyntaxHighlighter.brushes.PowerCLI.aliases = ['powercli', 'pcli'];
