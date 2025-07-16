# Ansible PowerShell Integration Demo

A project demonstrating a closed-loop automation workflow using Ansible to orchestrate custom PowerShell modules. This demo simulates a real-world IT process: provisioning a new backup client based on a service request from a ticketing system.

The automation uses mock APIs to represent ServiceNow and EMC NetWorker, allowing the entire workflow to be run locally.

---

## Workflow Overview

The automation performs the following steps in a loop for each available task:

1.  **Query Queue:** The main playbook queries a mock ServiceNow API for new, unassigned tasks in the "backup team" queue.
2.  **Assign Task:** For each found task, it updates the ticket to "Work in Progress" and assigns it to a virtual engineer.
3.  **Create Resource:** It reads the details from the ticket and makes a `POST` request to a mock NetWorker API to create the new client record.
4.  **Handle Failures:** If the creation fails (e.g., due to an invalid hostname), a `rescue` block catches the error, updates the ServiceNow ticket with the specific failure message, and returns it to the queue for human intervention.
5.  **Verify & Close:** On a successful creation, the playbook makes additional API calls to verify the client exists in NetWorker and that the ticket was updated correctly, then closes the ticket as "Closed Complete."

## Key Features

* **Custom PowerShell Modules:** Demonstrates writing bespoke Ansible modules in PowerShell to interact with REST APIs.
* **Resilient Error Handling:** Uses an Ansible `block`/`rescue` structure to gracefully handle failures and provide feedback.
* **Closed-Loop Automation:** The workflow not only performs an action but also updates the source ticket at every stage, from assignment to final closure.
* **Automated Verification:** The playbook uses `assert` tasks to verify that each step of the automation had the intended effect.
* **Automated Quality Gates:** The `start_lab.sh` script automatically runs linters before execution to ensure code quality.

## Getting Started

### Prerequisites

* Ansible
* PowerShell Core (pwsh)
* Python3 (for the mock APIs)

### Running the Lab

The entire lab environment and automation can be run with a single script.

1.  **Make the script executable** (only needs to be done once):
    ```bash
    chmod +x start_lab.sh
    ```

2.  **Run the lab:**
    ```bash
    ./start_lab.sh
    ```
This script will:
1.  Run the code scanners (`ansible-lint`, `PSScriptAnalyzer`).
2.  Start the mock ServiceNow and NetWorker APIs in the background.
3.  Run the Ansible playbook to process the tasks.
4.  Print the final state of the mock databases.
5.  Shut down the APIs.

## Project Structure

* `ansible/`: Contains the Ansible playbooks.
    * `library/`: Contains all the custom PowerShell modules. This is a special Ansible directory.
* `mock_apis/`: Contains the Python FastAPI code for the mock services.
* `start_lab.sh`: The main script to orchestrate the entire demo.

## Code Quality and Scanning

To ensure code quality and adherence to best practices, this project utilizes standard static analysis (linting) tools:

* **Ansible:** The playbooks are linted using `ansible-lint`.
    ```bash
    # To run the linter:
    ansible-lint ansible/
    ```

* **PowerShell:** All custom PowerShell modules are analyzed with `PSScriptAnalyzer`.
    ```powershell
    # To run the analyzer:
    Invoke-ScriptAnalyzer -Path ./ansible/library/
    ```