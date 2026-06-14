# strava_wrapper

A Phoenix LiveView app that fetches your Strava activity history and lets you filter by gear — no API calls on filter changes.

## Setup

```bash
cp .env.example .env   # set STRAVA_ACCESS_TOKEN
mix setup
source .env && mix phx.server
```

Visit [localhost:4000](http://localhost:4000).
