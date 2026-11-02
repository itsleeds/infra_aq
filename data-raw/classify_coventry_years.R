# Download and classify historical Coventry cycle infrastructure (2019-2026)
# Reproduces data-raw/coventry-cycleways-{year}.gpkg using Geofabrik West Midlands
# historical PBF snapshots and the R osmactive package.

library(osmactive)
library(sf)
library(dplyr)

years = 2019:2026
out_dir = "data-raw"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

required_cols = c(
  "highway", "bicycle", "surface", "smoothness", "service", "oneway",
  "segregated", "foot", "footway", "name", "width", "est_width",
  "cycleway", "cycleway_width", "cycleway_est_width",
  "cycleway_left", "cycleway_right",
  "cycleway_left_segregated", "cycleway_right_segregated"
)

ensure_columns = function(osm, cols) {
  missing_cols = setdiff(cols, names(osm))
  for (col in missing_cols) {
    osm[[col]] = NA_character_
  }
  osm
}

summary_rows = list()

for (year in years) {
  cat("=== Processing", year, "===\n")
  out_path = file.path(out_dir, paste0("coventry-cycleways-", year, ".gpkg"))
  geojson_path = file.path("/tmp/coventry_pbf", paste0("coventry-", year, ".geojson"))

  if (file.exists(geojson_path)) {
    osm = sf::st_read(geojson_path, quiet = TRUE)
    osm = ensure_columns(osm, required_cols)
    osm = osm[sf::st_is_valid(osm), ]
    osm = osm[!sf::st_is_empty(osm), ]

    cycle_net = get_cycling_network(osm)
    driving_net = get_driving_network(osm)
    cycle_net = distance_to_road(cycle_net, driving_net)

    cycle_net_classified = classify_cycle_infrastructure(
      cycle_net,
      include_mixed_traffic = FALSE
    )
    cycle_net_classified$year = year

    lower_names = tolower(names(cycle_net_classified))
    keep = !duplicated(lower_names)
    cycle_net_classified = cycle_net_classified[, keep]

    sf::st_write(cycle_net_classified, out_path, delete_dsn = TRUE, quiet = TRUE)
  } else if (file.exists(out_path)) {
    cycle_net_classified = sf::st_read(out_path, quiet = TRUE)
  } else {
    stop("Missing input for year ", year)
  }

  total_length_km = sum(sf::st_length(cycle_net_classified), na.rm = TRUE) |>
    units::set_units("km") |>
    as.numeric()

  summary_rows[[as.character(year)]] = data.frame(
    year = year,
    n_cycle_ways = nrow(cycle_net_classified),
    total_length_km = round(total_length_km, 2)
  )
}

summary_df = do.call(rbind, summary_rows)
print(summary_df)
write.csv(summary_df, file.path(out_dir, "coventry-cycleways-summary.csv"), row.names = FALSE)
