# Historical Analysis of Coventry’s Cycle Network (2019-2025)
Robin Lovelace
2026-11-02

# Introduction

This repository provides a reproducible analysis of the growth of
cycling infrastructure in Coventry from 2019 to 2025.

We compare a simple metric based solely on the `highway=cycleway`
OpenStreetMap (OSM) tag with the multi-layered classification system
implemented in the [`osmactive`](https://github.com/nptscot/osmactive) R
package.

# Detailed Infrastructure Growth (2019–2025)

The following code chunk and plot show the annual growth of the Coventry
cycle network across the specified years (`2019:2025`), broken down by
`osmactive` infrastructure categories.

``` r
stacked_data = cycle_data |>
  st_drop_geometry() |>
  group_by(year, cycle_segregation) |>
  summarise(
    length_km = sum(seg_length_m, na.rm = TRUE) / 1000,
    .groups = "drop"
  ) |>
  complete(year = years, cycle_segregation = factor(infra_levels, levels = infra_levels), fill = list(length_km = 0)) |>
  mutate(cycle_segregation = factor(cycle_segregation, levels = rev(infra_levels)))

p_stacked = ggplot(stacked_data, aes(x = factor(year), y = length_km, fill = cycle_segregation)) +
  geom_bar(stat = "identity", position = "stack") +
  scale_fill_manual(values = rev(get_palette_npt()), name = "Infrastructure Type") +
  labs(
    title = "Coventry Cycle Network Growth by Type (2019-2025)",
    subtitle = "Annual historical snapshots classified using osmactive",
    y = "Total Length (km)",
    x = "Year"
  ) +
  theme_minimal() +
  theme(
    legend.position = "right",
    axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1)
  )

ggsave("coventry_growth_chart.png", p_stacked, width = 8, height = 5, dpi = 150)
```

![Coventry Cycle Network Growth by Type
(2019-2025).](https://github.com/itsleeds/infra_aq/releases/download/v0.1.0/coventry_growth_chart.png)

``` r
summary_table = stacked_data |>
  mutate(cycle_segregation = factor(cycle_segregation, levels = infra_levels)) |>
  pivot_wider(names_from = cycle_segregation, values_from = length_km) |>
  mutate(
    Total = rowSums(across(all_of(infra_levels))),
    across(where(is.numeric) & !c(year), \(x) round(x, 2))
  ) |>
  rename(Year = year)

kable(summary_table, caption = "Classified cycling infrastructure length (km) in Coventry by year and type (2019-2025).")
```

| Year | Segregated Track (wide) | Off Road Path | Segregated Track (narrow) | Shared Footway | Painted Cycle Lane | Total |
|---:|---:|---:|---:|---:|---:|---:|
| 2019 | 0.14 | 14.74 | 4.49 | 2.33 | 4.71 | 26.41 |
| 2020 | 0.14 | 15.07 | 4.49 | 2.37 | 4.71 | 26.78 |
| 2021 | 0.47 | 15.07 | 4.33 | 2.38 | 4.71 | 26.96 |
| 2022 | 0.47 | 14.98 | 6.71 | 2.44 | 4.77 | 29.37 |
| 2023 | 0.48 | 15.61 | 7.00 | 2.70 | 5.69 | 31.47 |
| 2024 | 0.48 | 16.47 | 8.62 | 2.54 | 5.10 | 33.20 |
| 2025 | 0.80 | 16.58 | 7.96 | 6.80 | 5.10 | 37.23 |

Classified cycling infrastructure length (km) in Coventry by year and
type (2019-2025).

## Animated Growth Map

The spatial expansion of Coventry’s cycling network across `2019:2025`
is generated reproducibly below using `gganimate` and `gifski`:

``` r
anim_data = cycle_data |>
  mutate(
    display_year = as.integer(year),
    cycle_segregation = factor(cycle_segregation, levels = infra_levels)
  )

infra_colors = get_palette_npt()

p_anim = ggplot(anim_data) +
  geom_sf(aes(color = cycle_segregation), linewidth = 1) +
  scale_color_manual(values = infra_colors, drop = FALSE) +
  transition_manual(display_year) +
  labs(
    title = "Coventry Cycle Network Growth: {current_frame}",
    subtitle = "Year-by-year classified infrastructure (2019-2025)",
    color = "Infrastructure Type",
    caption = "Data: OpenStreetMap contributors (Geofabrik January snapshots)"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 14, hjust = 0.5),
    legend.position = "right",
    plot.margin = margin(10, 10, 10, 10)
  )

anim = animate(
  p_anim,
  nframes = length(years),
  fps = 1,
  renderer = gifski_renderer(),
  width = 800,
  height = 600,
  units = "px"
)
anim_save("coventry_historical_growth.gif", animation = anim)
```

![Animation showing Coventry Cycle Network Growth from 2019 to
2025.](https://github.com/itsleeds/infra_aq/releases/download/v0.1.0/coventry_historical_growth.gif)

# Simple Metric (`highway=cycleway`) and National Comparison

A common approach to quantifying cycling infrastructure is to filter for
segments where the `highway` tag is explicitly set to `cycleway`. Below
we compare Coventry’s `highway=cycleway` growth from 2019 to 2025
against the national trend for England (indexed to 2019 = 100).

``` r
england_growth = readRDS(england_rds) |>
  filter(year %in% years) |>
  arrange(year) |>
  mutate(index = length_km / first(length_km) * 100, region = "England")

cov_simple = cycle_data |>
  st_drop_geometry() |>
  filter(highway == "cycleway") |>
  group_by(year) |>
  summarise(length_km = sum(seg_length_m, na.rm = TRUE) / 1000, .groups = "drop") |>
  complete(year = years, fill = list(length_km = 0)) |>
  arrange(year) |>
  mutate(index = length_km / first(length_km) * 100, region = "Coventry")

comparison = bind_rows(
  england_growth |> select(year, length_km, index, region),
  cov_simple |> select(year, length_km, index, region)
)

p_comp = ggplot(comparison, aes(x = year, y = index, color = region)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = years) +
  scale_y_continuous(limits = c(95, NA)) +
  labs(
    title = "Relative Growth of Cycling Infrastructure: Coventry vs. England (2019-2025)",
    subtitle = "Index (2019 = 100) based on highway=cycleway length",
    y = "Growth Index (2019 = 100)",
    x = "Year",
    color = "Region"
  ) +
  theme_minimal()

ggsave("coventry_vs_england.png", p_comp, width = 8, height = 5, dpi = 150)
```

![Relative Growth of Cycling Infrastructure: Coventry vs. England
(2019-2025).](https://github.com/itsleeds/infra_aq/releases/download/v0.1.0/coventry_vs_england.png)

Between 2019 and 2025, England’s `highway=cycleway` network grew by
approximately 33%, whereas Coventry’s dedicated `highway=cycleway`
network grew by 114% (from 12.8 km in 2019 to 27.4 km in 2025). Across
all `osmactive` cycle infrastructure categories, Coventry’s network
expanded by 41% (from 26.4 km in 2019 to 37.2 km in 2025).
