import uuid
from fastapi import FastAPI, Response, Request, HTTPException
from pydantic import BaseModel, Field
from typing import List, Dict, Optional

# --- Pydantic Models ---

# This model now includes sensible defaults and allows extra fields to be ignored,
# making the API more robust.
class NewClient(BaseModel, extra="allow"):
    hostname: str
    tags: List[str] = []
    scheduledBackup: bool = True
    clientDirectEnabled: bool = False

# Model for updating a client (PATCH), all fields are optional.
class UpdateClient(BaseModel, extra="allow"):
    tags: Optional[List[str]] = None
    scheduledBackup: Optional[bool] = None
    state: Optional[str] = None


app = FastAPI()

# --- Mock Database with Pre-populated Clients ---
# Keys are now lowercase to ensure case-insensitive lookups.
mock_client_db: Dict[str, dict] = {
    # This client is active and can be unscheduled or retired.
    "dc01.f3.lan": {
        "hostname": "dc01.f3.lan",
        "tags": ["filesystem-win"],
        "scheduledBackup": True,
        "clientDirectEnabled": True,
        "state": "active",
        "clientId": "a8f8e1d2-c3b4-a596-a7b8-c9d0e1f2a3b4",
        "resourceId": {"id": "161.0.120.52.0.0.0.0.210.51.200.91.10.207.81.176", "sequence": 1}
    },
    # This client is also active and ready for updates.
    "sql-prod01.f3.lan": {
        "hostname": "sql-prod01.f3.lan",
        "tags": ["mssql"],
        "scheduledBackup": True,
        "clientDirectEnabled": True,
        "state": "active",
        "clientId": "b9e7d6c5-b4a3-9876-5432-10fedcba9876",
        "resourceId": {"id": "162.0.120.52.0.0.0.0.210.51.200.91.10.207.81.177", "sequence": 1}
    }
}


# --- API Endpoints ---

@app.get("/nwrestapi/v3/global/clients")
def find_clients(request: Request):
    """Finds clients. For this mock, it filters by hostname (case-insensitive)."""
    hostname_query = request.query_params.get('hostname')
    
    if not hostname_query:
        return {"clients": list(mock_client_db.values())}

    client = mock_client_db.get(hostname_query.lower())
    return {"clients": [client] if client else []}


@app.patch("/nwrestapi/v3/global/clients/{resource_id}")
def patch_client(resource_id: str, client_update: UpdateClient):
    """Updates an existing client record identified by its resourceId.id."""
    target_hostname = None
    for hostname, client in mock_client_db.items():
        if client["resourceId"]["id"] == resource_id:
            target_hostname = hostname
            break
            
    if not target_hostname:
        raise HTTPException(status_code=404, detail="Client not found")

    update_data = client_update.model_dump(exclude_unset=True)
    mock_client_db[target_hostname].update(update_data)
    
    print(f"--- NETWORKER API: PATCHED CLIENT '{target_hostname}' ---")
    print(mock_client_db[target_hostname])

    return {"client": mock_client_db[target_hostname]}


# In mock_apis/mock_networker_api.py

@app.post("/nwrestapi/v3/global/clients", status_code=201)
def create_client(client_data: NewClient, response: Response):
    """Creates a new NetWorker client resource with realistic ID generation."""
    key = client_data.hostname.lower()

    if key in mock_client_db:
        raise HTTPException(status_code=409, detail="Client with that hostname already exists")

    raw_uuid = uuid.uuid4()
    client_id = str(raw_uuid.hex) # Use .hex for a clean 32-char string
    resource_id = ".".join(str(b) for b in raw_uuid.bytes)
    
    new_resource_url = f"/nwrestapi/v3/global/clients/{resource_id}"

    record = client_data.model_dump()
    record.update({
        "hostname": key,
        "clientId": client_id,
        "resourceId": {"id": resource_id, "sequence": 1},
        "links": [{"href": new_resource_url, "rel": "item"}]
    })

    mock_client_db[key] = record
    response.headers["Location"] = new_resource_url
    
    print(f"--- NETWORKER API: CREATED CLIENT '{key}' ---")
    
    # --- THIS IS THE FIX ---
    # Return the new client ID in the response body
    return {"clientId": client_id}


@app.get("/debug/dump_db")
def dump_networker_db():
    """Returns the entire current state of the mock NetWorker database."""
    return mock_client_db