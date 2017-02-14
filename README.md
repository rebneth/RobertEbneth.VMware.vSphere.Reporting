# RobertEbneth.VMware.vSphere.Reporting

VMware Reporting Powershell Module and Scripts
used for VMware Health Check and documentation

Latest Update: February, 14th, 2017

CheckFilePathAndCreate		Function that is used in all Scripts for checking the specified filepath
Export-DatastoreProps		Exports the Overcommitment and VM# for each datastore to a csv file
Export-DSMultipathingStatus	Exports all Mulitpathing information for iSCSI and FC LUNs to a csv file
Export-ESXiProperties		Exports major ESXi properties including vSphere edition to a csv file
Export-ESXiSWReleases		Exports all installed ESXi software package information to a csv file
Export-iSCSISettings		Exports current iSCSI Initiator sttings and dynamic/static Bindings to a csv file
Export-PortGroupNicTeaming	Exports the Portgroup to VNIC and vmdk / Teaming properties to a csv file
Export-VIEvents				Exports the ESXi Events to a csv file
Export-VMDiskIOStat			Exports the VM Disk IO Statistic to a csv file
Export-VMHardDiskProps		Exports vmdk properties (location, size...) to a csv file
Export-VMProperties			Exports major important VM Properties to a csv file
Get-ESXiScratchLocation		Exports the current ESXi Scratch location to a csv file
Get-vCenterLicensing		Gets the registerd vCenter licenses