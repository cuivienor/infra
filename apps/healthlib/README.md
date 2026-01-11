# healthlib

Personal library for interacting with Garmin and Strava APIs.

## Setup

### 1. Create Strava Application

1. Go to https://www.strava.com/settings/api
2. Create an application (any name, localhost callback URL is fine)
3. Note your `Client ID` and `Client Secret`

### 2. Configure Secrets

Copy the example secrets file and encrypt with SOPS:

```bash
cd apps/healthlib/vars
cp healthlib_secrets.sops.yaml.example healthlib_secrets.sops.yaml

# Edit with your credentials
sops healthlib_secrets.sops.yaml
```

Add your Garmin credentials and Strava client credentials:

```yaml
garmin:
  email: "your-garmin-email@example.com"
  password: "your-garmin-password"

strava:
  client_id: "your-client-id"
  client_secret: "your-client-secret"
  access_token: ""
  refresh_token: ""
  expires_at: 0
```

### 3. Authenticate with Strava

Run the OAuth flow to get access tokens:

```bash
healthlib auth strava
```

This will:
1. Print a URL to visit
2. Ask you to authorize the app
3. Prompt for the authorization code from the redirect URL
4. Save tokens to your SOPS secrets file

## Usage

### Strava

```bash
# List recent activities
healthlib strava list
healthlib strava list --limit 50
healthlib strava list --json

# Get activity details
healthlib strava get 12345678
healthlib strava get 12345678 --json

# Update activity
healthlib strava update 12345678 --name "New Name"
healthlib strava update 12345678 --description "New description"
```

### Garmin

```bash
# List recent activities
healthlib garmin list
healthlib garmin list --limit 50
healthlib garmin list --json

# Get activity details
healthlib garmin get 12345678
healthlib garmin get 12345678 --json
```

## Library Usage

```python
from pathlib import Path
from healthlib.config import load_config
from healthlib.strava import StravaClient
from healthlib.garmin import GarminClient

secrets_path = Path("vars/healthlib_secrets.sops.yaml")
config = load_config(secrets_path)

# Strava
strava = StravaClient(config.strava, secrets_path)
activities = strava.list_activities(per_page=10)
for a in activities:
    print(f"{a.name} - {a.distance/1000:.1f}km")

# Update activity
strava.update_activity(12345678, name="Morning Run", description="Easy pace")

# Garmin
garmin = GarminClient(config.garmin)
activities = garmin.list_activities(limit=10)
for a in activities:
    print(f"{a.activity_name} - {a.activity_type}")

# Download activity file
garmin.download_activity(12345678, Path("./downloads"), file_format="fit")
```

## Environment Variables

Config can also be loaded from environment variables (overrides SOPS file):

```bash
export GARMIN_EMAIL="..."
export GARMIN_PASSWORD="..."
export STRAVA_CLIENT_ID="..."
export STRAVA_CLIENT_SECRET="..."
export STRAVA_ACCESS_TOKEN="..."
export STRAVA_REFRESH_TOKEN="..."
export STRAVA_EXPIRES_AT="..."
```

## Development

```bash
cd apps/healthlib

# Run tests
python -m pytest tests/ -v

# Type check
mypy healthlib/

# Lint
ruff check healthlib/ tests/
```

## Nix

Build with Nix:

```bash
nix build .#healthlib
```

Run from Nix:

```bash
nix run .#healthlib -- --help
```
