# mcp_resolve-claude_start.ps1
# Script to start DaVinci Resolve MCP server for Claude Desktop integration
# This is a convenience wrapper for the Claude Desktop integration

# Script variables
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
# Change to project root directory
Set-Location (Join-Path $scriptPath "..")
$projectRoot = Get-Location
$logFile = Join-Path $scriptPath "claude_resolve_server.log"
$configDir = Join-Path $env:APPDATA "Claude"
$configFile = Join-Path $configDir "claude_desktop_config.json"
$templateFile = Join-Path $scriptPath "config-templates\claude-desktop.template.json"

# Display banner
Write-Host "=============================================" -ForegroundColor Blue
Write-Host "  DaVinci Resolve - Claude Desktop Integration  " -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue

# Check if DaVinci Resolve is running
function Check-ResolveRunning {
    $resolve = Get-Process "Resolve" -ErrorAction SilentlyContinue
    if ($resolve) {
        Write-Host "✓ DaVinci Resolve is running" -ForegroundColor Green
        return $true
    }
    Write-Host "✗ DaVinci Resolve is not running" -ForegroundColor Red
    Write-Host "Please start DaVinci Resolve before continuing" -ForegroundColor Yellow
    return $false
}

# Check environment variables
function Check-Environment {
    Write-Host "Checking environment variables..." -ForegroundColor Yellow
    
    # Set default paths if not already set
    if (-not $env:RESOLVE_SCRIPT_API) {
        $env:RESOLVE_SCRIPT_API = "C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting"
    }
    if (-not $env:RESOLVE_SCRIPT_LIB) {
        $env:RESOLVE_SCRIPT_LIB = "C:\Program Files\Blackmagic Design\DaVinci Resolve\fusionscript.dll"
    }
    $env:PYTHONPATH = "$env:PYTHONPATH;$env:RESOLVE_SCRIPT_API\Modules\"
    $env:PYTHONUNBUFFERED = "1"
    
    # Log environment
    "Environment variables:" | Out-File -FilePath $logFile
    "RESOLVE_SCRIPT_API=$env:RESOLVE_SCRIPT_API" | Out-File -FilePath $logFile -Append
    "RESOLVE_SCRIPT_LIB=$env:RESOLVE_SCRIPT_LIB" | Out-File -FilePath $logFile -Append
    "PYTHONPATH=$env:PYTHONPATH" | Out-File -FilePath $logFile -Append
    
    # Check if files exist
    if (-not (Test-Path $env:RESOLVE_SCRIPT_API)) {
        Write-Host "✗ DaVinci Resolve API path not found: $env:RESOLVE_SCRIPT_API" -ForegroundColor Red
        return $false
    }
    
    if (-not (Test-Path $env:RESOLVE_SCRIPT_LIB)) {
        Write-Host "✗ DaVinci Resolve library not found: $env:RESOLVE_SCRIPT_LIB" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✓ Environment variables set correctly" -ForegroundColor Green
    return $true
}

# Setup Claude Desktop config
function Setup-ClaudeConfig {
    # Check if Claude Desktop config directory exists
    if (-not (Test-Path $configDir)) {
        Write-Host "Creating Claude Desktop config directory..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $configDir | Out-Null
    }
    
    # Check if Claude Desktop config file exists
    if (-not (Test-Path $configFile)) {
        Write-Host "Creating Claude Desktop configuration file..." -ForegroundColor Yellow
        
        # Check if template exists
        if (-not (Test-Path $templateFile)) {
            Write-Host "✗ Template file not found: $templateFile" -ForegroundColor Red
            return $false
        }
        
        # Copy and modify template
        Copy-Item $templateFile $configFile
        
        # Replace PROJECT_ROOT placeholder with actual path
        (Get-Content $configFile) -replace '\${PROJECT_ROOT}', $projectRoot.Path | Set-Content $configFile
        
        Write-Host "✓ Created Claude Desktop configuration file at $configFile" -ForegroundColor Green
    }
    else {
        Write-Host "✓ Claude Desktop configuration file exists" -ForegroundColor Green
    }
    
    return $true
}

# Main function
function Main {
    param (
        [string]$ProjectName,
        [switch]$Force
    )
    
    Write-Host "Starting DaVinci Resolve MCP Server for Claude Desktop..." -ForegroundColor Yellow
    
    # Initialize log file
    "Starting Claude-Resolve MCP Server at $(Get-Date)" | Out-File -FilePath $logFile
    
    # Check if Resolve is running, unless force mode is on
    if (-not $Force) {
        if (-not (Check-ResolveRunning)) {
            Write-Host "Waiting for DaVinci Resolve to start..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            if (-not (Check-ResolveRunning)) {
                Write-Host "DaVinci Resolve must be running. Please start it and try again." -ForegroundColor Red
                Write-Host "Or use -Force flag to bypass this check." -ForegroundColor Yellow
                return
            }
        }
    }
    else {
        Write-Host "Skipping DaVinci Resolve check due to force mode" -ForegroundColor Yellow
    }
    
    # Check environment
    if (-not (Check-Environment)) {
        Write-Host "Environment setup failed. Please check paths." -ForegroundColor Red
        return
    }
    
    # Setup Claude Desktop configuration
    if (-not (Setup-ClaudeConfig)) {
        Write-Host "Failed to setup Claude Desktop configuration." -ForegroundColor Red
        return
    }
    
    # Check if venv exists
    $venvDir = Join-Path $projectRoot "venv"
    if (-not (Test-Path $venvDir)) {
        Write-Host "Virtual environment not found. Please run setup.bat first." -ForegroundColor Red
        return
    }
    
    # Start the server
    Write-Host "Starting MCP server for Claude Desktop..." -ForegroundColor Green
    Write-Host "Connecting to DaVinci Resolve..." -ForegroundColor Blue
    
    # Start the server using Python
    $pythonCmd = Join-Path $venvDir "Scripts\python.exe"
    $serverScript = Join-Path $projectRoot "src\resolve_mcp_server.py"
    
    try {
        # Start server and capture output
        "Server starting at $(Get-Date)" | Out-File -FilePath $logFile

        # Create arguments array
        $pythonArgs = @($serverScript)
        if ($ProjectName) {
            Write-Host "Starting server with project: $ProjectName" -ForegroundColor Yellow
            $pythonArgs += "--project"
            $pythonArgs += $ProjectName
        }
        
        Write-Host "Running command: $pythonCmd $($pythonArgs -join ' ')" -ForegroundColor Yellow
        & $pythonCmd $pythonArgs *>&1 | Tee-Object -FilePath $logFile -Append
    }
    catch {
        Write-Host "Server failed to start or exited unexpectedly." -ForegroundColor Red
        $_.Exception.Message | Out-File -FilePath $logFile -Append
        Write-Host "Check the log file for details: $logFile" -ForegroundColor Yellow
        Get-Content $logFile
    }
    finally {
        Write-Host "Server process ended at $(Get-Date)" -ForegroundColor Yellow
    }
}

# Parse command line arguments
$projectName = $null
$force = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        { $_ -in "-p", "--project" } {
            $projectName = $args[++$i]
        }
        { $_ -in "-f", "--force" } {
            $force = $true
        }
        { $_ -in "-h", "--help" } {
            Write-Host "Usage: $($MyInvocation.MyCommand.Name) [OPTIONS]"
            Write-Host ""
            Write-Host "Options:"
            Write-Host "  -p, --project NAME    Attempt to open a specific DaVinci Resolve project"
            Write-Host "  -f, --force           Skip the DaVinci Resolve running check"
            Write-Host "  -h, --help            Display this help message"
            Write-Host ""
            exit
        }
    }
}

# Run main function with parsed arguments
Main -ProjectName $projectName -Force:$force
