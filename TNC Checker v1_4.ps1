#TNC Checker

# Get the current date and time
$currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss"

# Get the computer's NetBIOS name using System.Environment
$computerName = [System.Environment]::MachineName

# Define the log file name
$logFileName = "TNC_Checker_Log_" + "$computerName" + "_" + "$currentDateTime.txt"

# Get the current directory
$currentDirectory = Get-Location

# Define the JSON file path relative to the script directory
$jsonFilePath = Join-Path -Path $currentDirectory -ChildPath "firewall_rules.json"
# Load the JSON file content
$jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json

# Combine the current directory and log file name to get the full path
$logFilePath = Join-Path -Path $currentDirectory -ChildPath $logFileName
# Log initial message
Add-Content -Path $logFilePath -Value "TNC Checker results from source: $computerName. Date: $currentDateTime"

# Filter rules where the source matches the current computer's hostname
$sourceServer = $jsonContent.servers | Where-Object { $_.Hostname -eq $computerName }

# Check if the source server is found
if ($null -eq $sourceServer) {
    Write-Host "No server configuration found for the source: $computerName"
    Add-Content -Path $logFilePath -Value "No server configuration found for the source: $computerName"
    exit
}

# Filter rules where the source hostname matches the current computer's hostname
$filteredRules = $jsonContent.rules | Where-Object { $_.Sources -contains $sourceServer.Hostname }

# Check if there are any matching rules
if ($filteredRules.Count -eq 0) {
    Write-Host "No rules found for the source: $sourceServer.Hostname"
    Add-Content -Path $logFilePath -Value "No rules found for the source: $sourceServer.Hostname"
} else {
    # Loop through each matching rule
    foreach ($rule in $filteredRules) {
        foreach ($destination in $rule.Destinations) {
            foreach ($hostname in $destination.Hostnames) {
                $destServer = $jsonContent.servers | Where-Object { $_.Hostname -eq $hostname }
                
                foreach ($port in $destination.Ports) {
                    $name = $destServer.Hostname
                    $address = $destServer.IPAddress
                    $port = $port
                    $description = $destination.Description
                    
                    Write-Host "Checking connectivity from $($sourceServer.Hostname) to $name ($address) on port $port..."
                    
                    $result = Test-NetConnection -ComputerName $address -Port $port
                    
                    if ($result.TcpTestSucceeded) {
                        $message = "$name ($address) on port $port is reachable."
                        Write-Host $message -ForegroundColor Green
                    } else {
                        $message = "$name ($address) on port $port is not reachable."
                        Write-Host $message -ForegroundColor Red
                    }
                    
                    # Write the result to the log file
                    Add-Content -Path $logFilePath -Value "$($sourceServer.Hostname) to $message Description: $description"
                }
            }
        }
    }
}

Write-Host "Connectivity check completed."
Add-Content -Path $logFilePath -Value "Connectivity check completed."