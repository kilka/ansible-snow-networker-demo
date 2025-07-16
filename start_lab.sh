#!/bin/bash

# A script to launch the mock APIs, run the Ansible playbook, and clean up.

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

# Run the Ansible playbook
echo ""
echo "--- APIs started. Running Ansible playbook... ---"
ansible-playbook ansible/main.yml
echo "--- Playbook finished. ---"
echo ""

# --- UPDATED SECTION TO DISPLAY FINAL DB STATES ---
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
# ----------------------------------------------------

# Shut down the background API processes
echo "--- Shutting down mock APIs ---"
kill $SNOW_PID
kill $NETWORKER_PID

# Deactivate the virtual environment
deactivate

echo "Lab shutdown complete."