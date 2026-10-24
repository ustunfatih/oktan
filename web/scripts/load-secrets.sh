#!/bin/sh
# Loads the Google service account key into Cloudflare (production) and into .dev.vars (local dev).
# The key goes straight from the file into those two places; nothing is printed except the account email.
#
#   npm run setup:secrets -- /path/to/service-account-key.json
set -eu

KEY="${1:-}"
if [ -z "$KEY" ] || [ ! -f "$KEY" ]; then
  echo "Usage: npm run setup:secrets -- /path/to/service-account-key.json" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

# Validate the file and reduce it to one line of JSON.
COMPACT=$(node -e '
  const k = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (k.type !== "service_account" || !k.client_email || !k.private_key) {
    console.error("This is not a Google service account key file.");
    process.exit(1);
  }
  process.stdout.write(JSON.stringify({ client_email: k.client_email, private_key: k.private_key }));
' "$KEY")
EMAIL=$(printf '%s' "$COMPACT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.parse(s).client_email))')

echo "Service account: $EMAIL"

echo "1/2  Storing GOOGLE_SA_KEY as a Cloudflare secret on the 'oktan' Worker…"
printf '%s' "$COMPACT" | npx wrangler secret put GOOGLE_SA_KEY

echo "2/2  Writing .dev.vars for local development (uses the Oktan DEV sheet)…"
umask 077
{
  echo "SHEET_ID=1MJUHs2YSOssKJBL3neTz7zXSvzrm2ll4dIMJtgvYf58"
  echo "DEV_EMAIL=ustunfa@gmail.com"
  printf "GOOGLE_SA_KEY='%s'\n" "$COMPACT"
} > .dev.vars

echo "Done. You can now move the original key file somewhere safe (e.g. ~/Secrets) or delete it."
