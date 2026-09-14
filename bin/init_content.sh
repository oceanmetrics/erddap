#!/usr/bin/env bash
# bootstrap content/setup.xml from the CalCOFI known-good file, then review by hand
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
src="${1:-$HOME/Github/CalCOFI/erddap/content/setup.xml}"
[ -f "$src" ] || { echo "source setup.xml not found: $src"; exit 1; }
[ -f "$here/content/setup.xml" ] && { echo "content/setup.xml exists; not overwriting"; exit 0; }
cp "$src" "$here/content/setup.xml"
# values that must change; ERDDAP_* env vars in docker-compose override these at runtime anyway
sed -i.bak \
  -e 's#<baseHttpsUrl>.*</baseHttpsUrl>#<baseHttpsUrl>https://erddap.oceanmetrics.io</baseHttpsUrl>#' \
  -e 's#<adminInstitution>.*</adminInstitution>#<adminInstitution>Ocean Metrics LLC</adminInstitution>#' \
  "$here/content/setup.xml" && rm -f "$here/content/setup.xml.bak"
grep -q '<enableCors>' "$here/content/setup.xml" || \
  sed -i.bak 's#</erddapSetup>#<enableCors>true</enableCors>\n<corsAllowOrigin>*</corsAllowOrigin>\n</erddapSetup>#' "$here/content/setup.xml" && rm -f "$here/content/setup.xml.bak"
echo "wrote $here/content/setup.xml — review baseUrl, admin*, enableCors, then docker compose up -d"
