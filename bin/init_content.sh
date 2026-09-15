#!/usr/bin/env bash
# bootstrap content/setup.xml from the ERDDAP image's own template (no other checkout needed),
# then review by hand. ERDDAP_* env vars in docker-compose override these values at runtime.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tag="${ERDDAP_TAG:-v2.31.1}"
[ -f "$here/content/setup.xml" ] && { echo "content/setup.xml exists; not overwriting"; exit 0; }
if [ -n "${1:-}" ]; then
  cp "$1" "$here/content/setup.xml"
else
  docker run --rm "erddap/erddap:$tag" cat /usr/local/tomcat/content/erddap/setup.xml > "$here/content/setup.xml"
fi
sed -i.bak \
  -e 's#<baseHttpsUrl>.*</baseHttpsUrl>#<baseHttpsUrl>https://erddap.oceanmetrics.io</baseHttpsUrl>#' \
  -e 's#<adminInstitution>.*</adminInstitution>#<adminInstitution>Ocean Metrics LLC</adminInstitution>#' \
  "$here/content/setup.xml" && rm -f "$here/content/setup.xml.bak"
grep -q '<enableCors>' "$here/content/setup.xml" || \
  sed -i.bak 's#</erddapSetup>#<enableCors>true</enableCors>\n</erddapSetup>#' "$here/content/setup.xml" && rm -f "$here/content/setup.xml.bak"
echo "wrote $here/content/setup.xml (gitignored) — review baseUrl, admin*, enableCors, then docker compose up -d"
