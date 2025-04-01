@echo off
cd /d "%~dp0"
cd ..
echo Setting up DaVinci Resolve MCP Server environment...

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed. Please install Python 3.x and try again.
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment and install requirements
echo Activating virtual environment and installing requirements...
call venv\Scripts\activate.bat

REM Install MCP CLI
pip install modelcontextprotocol

REM Install other required packages
pip install requests

echo Setup complete! You can now run mcp_resolve-claude_start.bat
