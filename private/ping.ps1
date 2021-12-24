function Ping-It {
    param (
        [string] $Name,
        [int] $Port
    )
    $Splat = @{
        ComputerName  = $Name
        WarningAction = "SilentlyContinue"
        ErrorAction   = "SilentlyContinue"
    }

    [string] $HostName = $Name
    [string] $IP = ''
    [string] $PSTypeName = 'brsh.iptPing'
    [bool] $Success = $false
    [string[]] $DNSRecord = @('n/a')
    [bool] $PortAlive = $false

    if ($IsLinux) {

        $Splat.Count = 1
        $Splat.ResolveDestination = $true
        $Splat.IPv4 = $true

        $Ping = Test-Connection @Splat

        $HostName = $Ping.Destination
        $IP = $Ping.Address
        $Source = $Ping.Source
        $Success = if ($Ping.Status -match 'Success') { $true } else { $false }

        if ($Port) {
            $Splat.TCPPort = $Port
            $PSTypeName = 'brsh.iptPingPort'
            $Splat.Remove('Count')
            $PortPing = Test-Connection @Splat
        }
    } else {

        $Splat.InformationLevel = "Detailed"

        if ($Port) {
            $Splat.Port = $Port
            $PSTypeName = 'brsh.iptPingPort'
        }
        $ping = Test-NetConnection @Splat
        $HostName = $ping.ComputerName
        $IP = $ping.RemoteAddress
        $Source = $ping.SourceAddress
        $Success = if ($Ping.TcpTestSucceeded -or $Ping.PingSucceeded) { $true } else { $false }

        $DNSRecord = $ping.BasicNameResolution | ForEach-Object {
            if ($_.GetType().Name -match '_PTR') {
                    ($ping.BasicNameResolution).NameHost
                if ($HostName -match "\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}") {
                    $HostName = ($ping.BasicNameResolution).NameHost
                }
            } elseif ($_.GetType().Name -match '_A') {
                ($ping.BasicNameResolution).IPAddress
            } else {
                'Not Found'
            }
        }
    }

    [string] $HostShort = if ($HostName -match "\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}") {
        $HostName
    } else {
        if ($HostName.IndexOf('.') -gt 0) {
            $HostName.Substring(0, $HostName.IndexOf('.'))
        } else {
            $HostName
        }
    }

    [string] $TCPPort = if ($Port) { $Port } else { 'ICMP' }
    $hash = [ordered] @{
        PSTypeName    = $PSTypeName
        Host          = $HostName.ToLower()
        ShortName     = $HostShort
        IP            = $IP
        Source        = $Source
        Alive         = $Success
        Dead          = ! $Success
        Port          = $TCPPort
        PortName      = if ($TCPPort -eq 'ICMP') { $TCPPort.ToLower() } else { (Get-iptServicesEntry -port $TCPPort -Protocol TCP).Name }
        PortAlive     = $PortAlive
        DNSRecord     = $DNSRecord
        Interface     = 'n/a'
        RoundTripTime = - 1
    }

    if ($TCPPort -eq 'ICMP') { $hash.PortAlive = $Success }

    if ($IsLinux) {
        if ($PortPing -eq $true ) { $hash.PortAlive = $true } else { $hash.PortAlive = $false }
    } else {
        if ($Ping.TcpTestSucceeded -eq $false ) { $hash.PortAlive = $false }
        if ($Ping.TcpTestSucceeded -eq $true ) { $hash.PortAlive = $true }
        if ($Ping.PingSucceeded) { $hash.RoundTripTime = $ping.PingReplyDetails.RoundtripTime }
        $hash.Interface = $ping.InterfaceDescription
    }

    [PSCustomObject] $hash
}
