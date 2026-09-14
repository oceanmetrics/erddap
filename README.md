# erddap.oceanmetrics.io

Spec and deployment for the Ocean Metrics ERDDAP™ server. Created 2026-09-14.

## Why this server exists

Browser clients (DuckDB-WASM, plain `fetch`) can only read an ERDDAP that sends CORS headers and,
for the fast path, emits Parquet (ERDDAP ≥ 2.25). Most NOAA servers we depend on do neither
(CoastWatch West Coast, coastwatch.noaa.gov, AOML) — see the probe results in `bin/probe.sh`.
This ERDDAP:

1. runs with **`enableCors`** on and Parquet output available;
2. **re-serves upstream datasets** through `EDDGridFromErddap` / `EDDTableFromErddap` with
   `<redirect>false</redirect>`, so our server fetches, reformats and sends the data itself
   (the ERDDAP default is to redirect the client to the source, which would reintroduce the CORS
   problem);
3. later hosts Ocean Metrics' own tables (gazetteer places, precomputed place statistics) with
   `EDDTableFromParquetFiles` or DuckDB-backed `EDDTableFromDatabase` as in CalCOFI.

First consumer: `oceanmetrics/erddap-places` (place-based statistics computed in the browser).

## Template

The CalCOFI deployment (`CalCOFI/server` + `CalCOFI/erddap`): custom image
`FROM erddap/erddap:${ERDDAP_TAG}` plus the DuckDB JDBC jar, content directory bind-mounted at
`/usr/local/tomcat/content/erddap`, `ERDDAP_*` environment overrides, Caddy reverse proxy with a
guard against unconstrained bulk downloads. Differences here: CORS on, `EDD*FromErddap` datasets,
smaller memory.

## Layout

```
docker-compose.yml     erddap service (+ optional caddy snippet reference)
.env.example           ERDDAP_flagKeyKey, ERDDAP_TAG, memory
content/datasets.xml   dataset definitions (start: three re-served CoastWatch/AOML grids)
content/setup.xml      NOT committed until reviewed; bootstrap with bin/init_content.sh
caddy/Caddyfile.erddap vhost block to paste into the host's Caddyfile
bin/init_content.sh    copies a known-good setup.xml (CalCOFI) and sets institution values
bin/probe.sh           CORS + Parquet probe used to verify any ERDDAP from a browser's point of view
```

## Deployment checklist

- [ ] Decide host (D7 in the private plan): the msens Docker host (already runs Caddy) or a new VM. ERDDAP wants ~2–4 GB RAM and local disk under `/erddapData` for its cache.
- [ ] DNS: `erddap.oceanmetrics.io` A/CNAME → host (no record exists as of 2026-09-14).
- [ ] `bin/init_content.sh` → review `content/setup.xml` (baseHttpsUrl, admin*, `enableCors`).
- [ ] `docker compose up -d --build`; add `caddy/Caddyfile.erddap` to the host Caddyfile; reload.
- [ ] `bin/probe.sh https://erddap.oceanmetrics.io` → expect `Access-Control-Allow-Origin` and a readable `.parquet`.
- [ ] Confirm each re-served dataset loads (`/erddap/griddap/index.html`) and that a griddap `.parquet` subset for a sanctuary bbox returns in seconds, not minutes (non-redirect mode proxies every byte).

## Upstream datasets re-served first

| datasetID (ours) | Source | Why |
| --- | --- | --- |
| `jplMURSST41` | https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41 | 1 km SST; the small-place / area-weights showcase |
| `noaacwNPPVIIRSchlaDaily` | https://coastwatch.noaa.gov/erddap/griddap/noaacwNPPVIIRSchlaDaily | chlorophyll |
| `noaa_aoml_seascapes_8day` | https://cwcgom.aoml.noaa.gov/erddap/griddap/noaa_aoml_seascapes_8day | categorical seascape classes |

Global CRW 5 km products are read directly from PacIOOS (CORS on, ERDDAP 2.29) and need no proxy.

## Notes

- ERDDAP version observed on CoastWatch West Coast on 2026-09-14: 2.31.1.
- CORS setting: `enableCors` in setup.xml (or `ERDDAP_enableCors=true`), off by default since 2.27; `corsAllowOrigin` restricts origins if wanted.
- Load: with `<redirect>false</redirect>` the upstream request, reformat and response all pass through this server; keep `ERDDAP_MEMORY` ≥ 2g and watch `/erddap/status.html`.
