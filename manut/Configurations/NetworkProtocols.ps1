function Disable-UnusedProtocols {
    param([Logger] $Log)

    $protocols = @(
        @{ Id = "ms_tcpip6"; Name = "IPv6" },
        @{ Id = "ms_rspndr"; Name = "Responder (RSPNDR)" },
        @{ Id = "ms_lltdio"; Name = "Link-Layer Topology Discovery (LLTDIO)" },
        @{ Id = "ms_lldp";   Name = "LLDP" }
    )

    $Log.Info("Disabling unnecessary network protocols...")
    $adapters = Get-NetAdapter -Name "*"

    foreach ($adapter in $adapters) {
        foreach ($proto in $protocols) {
            Disable-NetAdapterBinding -Name $adapter.Name -ComponentID $proto.Id -ErrorAction SilentlyContinue
        }
    }
    $Log.Success("Protocols disabled on all adapters.")
}
