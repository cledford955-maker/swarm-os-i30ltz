#!/usr/bin/env bash
# Build the SWARM OS Flutter shell as a mock web demo (for Vercel).
# Output: /mnt/Lucy/10-releases/web-demo/  (static site + vercel.json)
# Deploy: cd /mnt/Lucy/10-releases/web-demo && npx vercel deploy --prod
set -euo pipefail

ROOT=/mnt/Lucy
OUT="$ROOT/10-releases/web-demo"
export PATH="$ROOT/30-source/flutter-sdk/bin:$PATH"

cd "$ROOT/30-source/frontend"
flutter build web --release -t lib/main_web.dart --dart-define=MOCK=true \
  --no-wasm-dry-run --output "$OUT"

# Don't publish the companion APK with a public demo.
rm -rf "$OUT/assets/assets/companion"

cat > "$OUT/vercel.json" <<'JSON'
{
  "rewrites": [{ "source": "/((?!.*\\.).*)", "destination": "/index.html" }],
  "headers": [
    { "source": "/(.*)", "headers": [{ "key": "X-Robots-Tag", "value": "noindex" }] }
  ]
}
JSON
echo "Built $OUT ($(du -sh "$OUT" | cut -f1))"
