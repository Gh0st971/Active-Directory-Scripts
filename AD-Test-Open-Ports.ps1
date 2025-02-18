# Script to test if the ports used by Active Directory are open

# Define the list of Active Directory servers and ports
$servers = @("192.168.1.10","192.168.1.11","192.168.1.12")
$ports = @(53, 88, 135, 139, 389, 445, 3268, 3843)

# Function to check if a port is open
function Test-Port {
    param (
        [string]$server,
        [int]$port
    )
    try {
        $tcpConnection = Test-NetConnection -ComputerName $server -Port $port -WarningAction SilentlyContinue
        if ($tcpConnection.TcpTestSucceeded) {
            Write-Output "${server}:{$port} is open"
        } else {
            Write-Output "${server}:{$port} is closed"
        }
    } catch {
        Write-Output "Error connecting to ${server}:{$port}"
    }
}

# Execute the check for each combination of server and port
foreach ($server in $servers) {
    foreach ($port in $ports) {
        Test-Port -server $server -port $port
    }
}