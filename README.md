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
content/setup.xml      gitignored; bootstrap with bin/init_content.sh (template from the image)
caddy/Caddyfile.erddap vhost block to paste into the host's Caddyfile
bin/init_content.sh    copies a known-good setup.xml (CalCOFI) and sets institution values
bin/probe.sh           CORS + Parquet probe used to verify any ERDDAP from a browser's point of view
```

## Deployment checklist

- [x] Host: the msens Docker host (16 GB RAM, ~7 GB free on 2026-09-15; Caddy already there). Checkout lives at `/share/github/oceanmetrics/erddap`.
- [x] DNS: wildcard `*.oceanmetrics.io` A → the host (2026-09-15).
- [ ] `bin/init_content.sh` (pulls the template from the image) → review `content/setup.xml` (gitignored; real values come from `ERDDAP_*` env in compose).
- [ ] `cp .env.example .env` (set `ERDDAP_flagKeyKey`), `docker compose up -d` (joins the host Caddy's `server_default` network); host Caddyfile gets one line, `import /share/github/oceanmetrics/erddap/caddy/Caddyfile.erddap`; `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`.
- [ ] `bin/probe.sh https://erddap.oceanmetrics.io` → expect `Access-Control-Allow-Origin` and a readable `.parquet`.
- [ ] Confirm each re-served dataset loads (`/erddap/griddap/index.html`) and that a griddap `.parquet` subset for a sanctuary bbox returns in seconds, not minutes (non-redirect mode proxies every byte).

## Upstream datasets re-served first

| datasetID (ours) | Source | Why |
| --- | --- | --- |
| `jplMURSST41` | https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41 | 1 km SST; the small-place / area-weights showcase |
| `noaacwNPPVIIRSchlaDaily` | https://coastwatch.noaa.gov/erddap/griddap/noaacwNPPVIIRSchlaDaily | chlorophyll |
| `noaa_aoml_seascapes_8day` | https://cwcgom.aoml.noaa.gov/erddap/griddap/noaa_aoml_seascapes_8day | categorical seascape classes |

## USF IMaRS grids re-served (2026-10-07)

Source: Tylar Murray's https://erddap.marine.usf.edu/erddap (ERDDAP 2.25, no CORS). Same datasetIDs,
`EDDGridFromErddap` + `redirect=false`. Probe from the laptop on 2026-10-07: `griddap/<id>.json?time[(last)]`,
`Access-Control-Allow-Origin` on `/info/<id>/index.json` (ERDDAP echoes the request Origin), and a `.parquet`
of the last time step (surface depth) over a 0.5° Florida Keys box (24.5–25 N, 81–80.5 W).

| datasetID | variables | json | CORS | parquet | bytes | s |
| --- | --- | --- | --- | --- | --- | --- |
| `CMEMS_PHY_MONTHLY` | so (surface only) | 200 | yes | 200 | 1226 | 0.42 |
| `cmems_salinity` | so (50 depths) | 200 | yes | 200 | 1464 | 0.42 |
| `cmems_biogeochem_nutrients` | fe, no3, po4, si | 200 | yes | 200 | 1228 | 0.37 |
| `cmems_biogeochem_phyto` | chl, phyc | 200 | yes | 200 | 1224 | 0.40 |
| `cmems_biogeochem_pp` | nppv, o2 | 200 | yes | 200 | 1233 | 0.38 |
| `cmems_biogeochem_carbon` | dissic, ph, talk | 200 | yes | 200 | 1216 | 0.42 |
| `cmems_biogeochem_co2` | spco2 | 200 | yes | 200 | 1045 | 0.39 |
| `cmems_biogeochem_zoo` | zooc | 200 | yes | 200 | 1230 | 0.38 |
| `cmems_biogeochem_optics` | kd | 200 | yes | 200 | 1218 | 0.40 |
| `cmems_altimetry` | mlotst, tob (bottomT), sob, zos, sea ice | 200 | yes | 200 | 1280 | 0.39 |
| `IMERG_monthly_global_precip` | precipitation, precipitationQualityIndex, randomError | 200 | yes | 200 | 1340 | 0.39 |
| `jplMURSST41anom1day` | sstAnom, mask | 404 | yes | 404 | – | – |
| `jplMURSST41mday` | sst, nobs, mask | 404 | yes | 404 | – | – |
| `moda_npp_mo_glob` | npp | 200 | yes | 200 | 1400 | 0.46 |

Caveats:

- No `thetao` on the USF server; `cmems_altimetry` (not on the original list) is the only USF source of `mlotst` and bottom temperature (`tob`).
- `CMEMS_PHY_MONTHLY` holds only surface `so`, and it is NaN everywhere we sampled (also at the source), with ~2-day steps despite the name. Use `cmems_salinity` for salinity.
- The two MUR datasets on the USF server are themselves redirects to `coastwatch.pfeg.noaa.gov`, which was unreachable from both the laptop and msens on 2026-10-07 (connection timeout), so they did not load. ERDDAP retries failed datasets at each major load (every 15 min), so they should appear once CoastWatch West Coast is back. Both are huge (0.01°, 17999 × 36000 per step; anom1day has 8878 steps); subset tightly.
- The bare `griddap/<id>.json` is rejected by the Caddy guard (400) by design; add any constraint.

Global CRW 5 km products are read directly from PacIOOS (CORS on, ERDDAP 2.29) and need no proxy.

## Notes

- ERDDAP version observed on CoastWatch West Coast on 2026-09-14: 2.31.1.
- CORS setting: `enableCors` in setup.xml (or `ERDDAP_enableCors=true`), off by default since 2.27. Leave `corsAllowOrigin` UNSET to allow every origin: with `*` ERDDAP 2.31 answers `Access-Control-Allow-Origin: <origin>.origin-not-allowed.invalid` (verified 2026-09-15); set it only to a comma-separated list of origins to restrict.
- Load: with `<redirect>false</redirect>` the upstream request, reformat and response all pass through this server; keep `ERDDAP_MEMORY` ≥ 2g and watch `/erddap/status.html`.
