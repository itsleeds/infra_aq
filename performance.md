# Performance Comparison: R osmactive vs Rust atf-lab/osmactive
Robin Lovelace
2026-11-02

# Overview

We benchmarked the historical extraction and classification pipeline for
Coventry (`2019:2025`) comparing the
[`nptscot/osmactive`](https://github.com/nptscot/osmactive) R package
workflow against the new Rust CLI crates (`osmget` and
[`atf-lab/osmactive`](https://github.com/atf-lab/osmactive)).

# Benchmarks

- **PBF Extraction (`osmget extract` vs Python `pyosmium` /
  `osmextract`)**: Extracting the 5,865–9,508 highway ways intersecting
  the Coventry bounding box from a ~50 MB West Midlands `.osm.pbf` file
  into GeoParquet takes **~1.9–2.1 seconds** per year in pure Rust
  using:

``` bash
osmget extract --profile all --preserve-other-tags --bbox -1.56,52.40,-1.45,52.43 --intersects \
  geofabrik_west-midlands-190101.osm.pbf coventry-2019.parquet
```

- **Infrastructure Classification (`osmactive` R package vs Rust
  `osmactive`)**:
  - Running the R `osmactive` pipeline (`get_cycling_network()`,
    `get_driving_network()`, `distance_to_road()`,
    `classify_cycle_infrastructure()`) on the extracted Coventry network
    takes **~0.6–1.4 seconds** per year once the ways are loaded in
    memory.
  - Running the Rust `atf-lab/osmactive` pipeline (`osmactive access` in
    **~0.08 s** + `osmactive cycle-infra` in **~4.1 s** including
    England-wide ONS Built-up Areas spatial join and 5 m point-sampled
    road distance calculation) processes the full GeoParquet table
    directly and additionally computes UK LTN 1/20 and Cycling by Design
    Level of Service (`los`):

``` bash
osmactive access --input coventry-2019.parquet --output coventry-2019-access.parquet --rules rules/gb.toml
osmactive cycle-infra --input coventry-2019-access.parquet --output coventry-2019-cycle.parquet \
  --built-up bua_2022_gb.geojson
```

- **Combined Fast Workflow**: Using `osmget` (Rust) to slice regional
  historical `.osm.pbf` files in ~2 seconds per snapshot and feeding the
  resulting geometries into `osmactive` reduces multi-year historical
  processing for a city from minutes to a few seconds.
