#!/usr/bin/env bash
# probe an ERDDAP from a browser's point of view: version, CORS header, Parquet support
# usage: bin/probe.sh https://erddap.oceanmetrics.io [griddap_dataset_id]
set -euo pipefail
base="${1%/}"; ds="${2:-}"
echo "version: $(curl -s -m 20 "$base/erddap/version")"
echo "-- CORS on /erddap/info (Origin: https://oceanmetrics.io)"
curl -s -m 20 -o /dev/null -D - -H 'Origin: https://oceanmetrics.io' "$base/erddap/info/index.json?page=1&itemsPerPage=1" | grep -i 'HTTP/\|access-control' || true
if [ -n "$ds" ]; then
  echo "-- parquet output for $ds (first time step, tiny bbox)"
  curl -s -m 120 -o /tmp/probe.parquet -w 'status=%{http_code} bytes=%{size_download}\n' \
    -H 'Origin: https://oceanmetrics.io' "$base/erddap/griddap/$ds.parquet?"
  command -v duckdb >/dev/null && duckdb -c "DESCRIBE SELECT * FROM '/tmp/probe.parquet'" || true
fi
