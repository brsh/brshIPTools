function Format-ServicesFile {
	param (
		$Object,
		[string] $Extension = ''
	)

	$Ext = if ($Extension.Trim().Length -gt 0) {
		$Extension.Trim()
	} else {

	}

	[PSCustomObject]@{
		Name      = $Object.Name
		Path      = $Object.FullName
		Extension = $Ext
	}
}
