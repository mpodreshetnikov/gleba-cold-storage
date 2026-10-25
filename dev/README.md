# Development

## Build the mod zip

```sh
v=$(python3 -c "import json; print(json.load(open('info.json'))['version'])")
git archive --format=zip --prefix=gleba-cold-storage_$v/ -o gleba-cold-storage_$v.zip HEAD
```

`dev/` and `docs/` are left out of the zip by `.gitattributes`.

## In-game tests

`dev/tests` is a small mod (`gcs-tests`) that builds a test map on its first tick and logs
`GCS-TEST PASS|FAIL ...` lines. Run it with the Factorio headless server, which includes Space Age data:

```sh
# link this repo as mods/gleba-cold-storage and dev/tests as mods/gcs-tests, enable both
./bin/x64/factorio --create test.zip
./bin/x64/factorio --benchmark test.zip --benchmark-ticks 18300
grep GCS-TEST factorio-current.log
```

`dev/tests/sim.py` runs the temperature model on its own; the expected slowdowns in the tests come from it.

`dev/bench-a` (1000 chambers + 300 vaults, all full) and `dev/bench-b` (the same layout with plain chests)
measure the cost; compare `scriptUpdate` from `--benchmark-verbose all`.

The headless server does not load sprites, so sprite sizes are not checked there.

## Graphics tools

`dev/tools` holds the Python (Pillow, numpy) scripts that import the CMA Graphics sprites, generate the
frost overlay, icons and thumbnail, and render the review previews. They expect an unpacked
[cma-graphics](https://mods.factorio.com/mod/cma-graphics) mod at `$CMA_ROOT` (default `./cma-graphics`).
