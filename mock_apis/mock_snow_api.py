import re
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
from typing import Optional

# --- Pydantic Models ---
class TaskUpdate(BaseModel):
    assigned_to: Optional[str] = None
    work_notes: Optional[str] = None
    state: Optional[str] = None
    close_notes: Optional[str] = None

# --- FastAPI App ---
app = FastAPI()

# --- Mock Database with Edge Case Task ---
mock_db = {
    # --- ADD THIS NEW EDGE CASE TASK ---
    "ffffffffffffffffffffffffffffffff": {
        "number": "SCTASK001000",
        "sys_id": "ffffffffffffffffffffffffffffffff",
        "state": "new",
        "assigned_to": "",
        "assignment_group": "backup team",
        "work_notes": "",
        "short_description": "Provision New Backup: badhost.f3.lan",
        "u_backup_server": "networker-prod-1.f3.lan", # This hostname will fail to resolve
        "u_backup_tag": "mssql",
        "ci_fqdn": "badhost.f3.lan",
        "client_id_from_networker": ""
    },
    # ------------------------------------
    "a1a2a3a4b5b6c7d8e9f0a1b2c3d4e5f6": {
        "number": "SCTASK001001",
        "sys_id": "a1a2a3a4b5b6c7d8e9f0a1b2c3d4e5f6",
        "state": "new",
        "assigned_to": "",
        "assignment_group": "backup team",
        "work_notes": "",
        "short_description": "Provision New Backup: db01.f3.lan",
        "u_backup_server": "networker-prod.f3.lan",
        "u_backup_tag": "mssql",
        "ci_fqdn": "db01.f3.lan",
        "client_id_from_networker": "d5b545cb000000045bc834515bc83450"
    },
    # ... (the rest of your mock_db remains the same)
    "c1c2c3c4d5d6e7f8a9b0c1d2e3f4a5b6": {
        "number": "SCTASK001002",
        "sys_id": "c1c2c3c4d5d6e7f8a9b0c1d2e3f4a5b6",
        "state": "new",
        "assigned_to": "",
        "assignment_group": "storage team",
        "work_notes": "",
        "short_description": "Provision New Backup: web03.f3.lan",
        "u_backup_server": "networker-prod.f3.lan",
        "u_backup_tag": "filesystem-win",
        "ci_fqdn": "web03.f3.lan",
        "client_id_from_networker": "a1b2c3d4000000045bc834515bc83450"
    },
    "e1e2e3e4f5f6a7b8c9d0e1f2a3b4c5d6": {
        "number": "SCTASK001003",
        "sys_id": "e1e2e3e4f5f6a7b8c9d0e1f2a3b4c5d6",
        "state": "work in progress",
        "assigned_to": "Some Guy",
        "assignment_group": "backup team",
        "work_notes": "",
        "short_description": "Provision New Backup: syb-prod01.f3.lan",
        "u_backup_server": "networker-prod.f3.lan",
        "u_backup_tag": "sybase",
        "ci_fqdn": "syb-prod01.f3.lan",
        "client_id_from_networker": "b2c3d4e5000000045bc834515bc83450"
    },
    "g1g2g3g4h5h6i7j8k9l0a1b2c3d4e5f6": {
        "number": "SCTASK001004",
        "sys_id": "g1g2g3g4h5h6i7j8k9l0a1b2c3d4e5f6",
        "state": "new",
        "assigned_to": "",
        "assignment_group": "backup team",
        "work_notes": "",
        "short_description": "Provision New Backup: app-lnx01.f3.lan",
        "u_backup_server": "networker-prod.f3.lan",
        "u_backup_tag": "filesystem-unix",
        "ci_fqdn": "app-lnx01.f3.lan",
        "client_id_from_networker": "c3d4e5f6000000045bc834515bc83450"
    }
}

# --- API Endpoints ---
@app.get("/api/now/v2/table/sc_task")
def get_sc_task(request: Request):
    sysparm_query = request.query_params.get('sysparm_query')
    results = list(mock_db.values())
    if sysparm_query:
        filtered_results = []
        conditions = sysparm_query.split('^')
        for record in results:
            matches_all = True
            for cond in conditions:
                if 'ISEMPTY' in cond:
                    key = cond.replace('ISEMPTY', '')
                    if record.get(key, "").strip() != "":
                        matches_all = False
                        break
                elif '=' in cond:
                    key, value = cond.split('=', 1)
                    if str(record.get(key)) != value:
                        matches_all = False
                        break
            if matches_all:
                filtered_results.append(record)
        results = filtered_results
    return {"result": results}

@app.get("/api/now/v2/table/sc_task/{sys_id}")
def get_single_sc_task(sys_id: str):
    if sys_id in mock_db:
        return {"result": mock_db[sys_id]}
    raise HTTPException(status_code=404, detail="Task not found")

@app.patch("/api/now/v2/table/sc_task/{sys_id}")
def update_sc_task(sys_id: str, ticket_data: TaskUpdate):
    if sys_id in mock_db:
        update_data = ticket_data.model_dump(exclude_unset=True)
        if 'work_notes' in update_data:
            existing_notes = mock_db[sys_id].get('work_notes', '')
            new_notes = update_data['work_notes']
            mock_db[sys_id]['work_notes'] = f"{existing_notes}\n{new_notes}".strip()
            del update_data['work_notes']
        mock_db[sys_id].update(update_data)
        print(f"--- SCTASK API: UPDATED TASK {sys_id}: {mock_db[sys_id]}")
        return {"result": mock_db[sys_id]}
    return {"error": "Task not found"}, 404

# Add this function to the end of mock_snow_api.py

@app.get("/debug/dump_db")
def dump_snow_db():
    """Returns the entire current state of the mock ServiceNow database."""
    return mock_db