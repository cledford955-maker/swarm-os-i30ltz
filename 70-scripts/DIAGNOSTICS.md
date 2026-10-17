# SWARM diagnostic bundles

In the SWARM shell, open **Telemetry → Export diagnostics → Save diagnostic bundle**.
Choose a destination folder. The saved archive path appears in the panel; collection
errors appear there too. Enable **Include recent SWARM service logs** when service
startup or runtime failures need investigation.

The collector runs locally on whichever OS is running the shell. Running it on
CachyOS reports CachyOS; it does not inspect an offline SWARM installation or prove
that an ISO boots.

For terminal use on the development drive:

```sh
/mnt/Lucy/70-scripts/collect_swarm_diagnostics.py --output-dir /mnt/Lucy/10-releases/diagnostics
```

On a newly built SWARM system:

```sh
swarm-diagnostics --output-dir "$HOME/swarm-diagnostics"
```

Add `--include-journal` for up to 150 current-boot journal lines per SWARM system
service. Normal user permissions apply: inaccessible journals are recorded as
errors, and the collector never invokes sudo. Each command has a 10-second timeout,
health requests have a 3-second timeout, and captured output is limited to 128 KiB
per entry. Missing services/tools and unhealthy endpoints are report data, not
reasons to discard the rest of the bundle.

The `.tar.gz` contains `report.json` and a README. It is created with owner-only
permissions and a unique filename; previous bundles are not overwritten. It
collects no `.env` files, process environments, application databases, or source
trees, and uploads nothing. Common secret assignments, HTTP credentials, provider
key formats, and private key blocks are redacted. This is best-effort filtering,
not a guarantee: review the report before sharing, especially service journals.
Paths and disk details may identify the machine.

The canonical ISO builder stages the collector as `/usr/local/bin/swarm-diagnostics`;
`packages.x86_64` includes its Python runtime. No backend service or API key is
required to export a bundle.

Validation:

```sh
python3 -m unittest discover -s 70-scripts/tests -p test_diagnostics.py
cd 30-source/frontend
../flutter-sdk/bin/flutter test test/diagnostics_export_test.dart
```
