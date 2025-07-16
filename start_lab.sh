#!/bin/bash

# A script to lint the code, launch the mock APIs, run the Ansible playbook, and clean up.

# --- Step 1: Code Scanning (Linting) ---
echo "--- Running Code Scanners ---"

echo "Running ansible-lint..."
ansible-lint ansible/
# Check the exit code of the last command. If it's not 0, an error occurred.
if [ $? -ne 0 ]; then
    echo "ERROR: ansible-lint found fatal errors. Aborting."
    exit 1
fi

echo "Running PSScriptAnalyzer..."
# Run the PowerShell linter command. We check only for Errors.
pwsh -Command "Invoke-ScriptAnalyzer -Path ./ansible/library/ -Severity Error"
if [ $? -ne 0 ]; then
    echo "ERROR: PSScriptAnalyzer found errors. Aborting."
    exit 1
fi

echo "Code scanning passed."
echo ""


# --- Step 2: Start Mock Lab Environment ---
echo "--- Starting Mock Lab Environment ---"

# Activate Python virtual environment
source ./mock_apis/venv/bin/activate

# Start mock ServiceNow API on port 8000 in the background
echo "Starting mock ServiceNow API..."
uvicorn mock_apis.mock_snow_api:app --host 127.0.0.1 --port 8000 > snow_api.log 2>&1 &
SNOW_PID=$!

# Start mock NetWorker API on port 8001 in the background
echo "Starting mock NetWorker API..."
uvicorn mock_apis.mock_networker_api:app --host 127.0.0.1 --port 8001 > networker_api.log 2>&1 &
NETWORKER_PID=$!

# Give the servers a moment to start up
sleep 3


# --- Step 3: Run the Ansible Playbook ---
echo ""
echo "--- APIs started. Running Ansible playbook... ---"
ansible-playbook ansible/main.yml
echo "--- Playbook finished. ---"
echo ""


# --- Step 4: Display Final State and Clean Up ---
echo "############################################################"
echo "###           FINAL STATE OF MOCK DATABASES              ###"
echo "############################################################"
echo ""
echo "--- Final State of ServiceNow DB ---"
curl -s http://localhost:8000/debug/dump_db | jq .
echo ""
echo "--- Final State of NetWorker DB ---"
curl -s http://localhost:8001/debug/dump_db | jq .
echo ""

# Shut down the background API processes
echo "--- Shutting down mock APIs ---"
kill $SNOW_PID
kill $NETWORKER_PID

# Deactivate the virtual environment
deactivate

echo "Lab shutdown complete."