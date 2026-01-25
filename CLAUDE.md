# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Load package for development (run from R console)
devtools::load_all()

# Check package (runs R CMD check)
devtools::check()

# Build documentation from roxygen2 comments
devtools::document()

# Install package locally
devtools::install()
```

## Architecture

pelotonR is an R package that provides an interface to the Peloton fitness API. It follows standard R package structure.

### Authentication

All API requests require a bearer token set via the `PELOTON_BEARER_TOKEN` environment variable. The token is obtained from the Peloton web app's network requests. There is no login flow - the deprecated `peloton_auth()` function is a no-op.

### Core Components

**`peloton_api.R`** - The foundational HTTP layer. `peloton_api(path, query)` makes authenticated GET requests to `api.onepeloton.com` and returns parsed JSON. All query functions build on this.

**`queries.R`** - High-level query functions that wrap `peloton_api()`:
- `get_my_info()` - Returns user metadata including user ID
- `peloton_user_id()` - Convenience function to get just the user ID
- `get_all_workouts(userid, num_workouts, joins, limit_per_page)` - Lists workouts with automatic pagination. Auto-fetches userid if not provided. Supports `joins` parameter for including ride/instructor data.
- `get_workout_data(workout_id)` - Details for a specific workout
- `get_performance_graphs(workout_ids)` - Time-series metrics (cadence, output, etc.)

Most query functions are vectorized via `purrr::map_df()` to accept multiple IDs.

Note: `get_all_workouts2()` is deprecated and redirects to `get_all_workouts()`.

**`parsing.R`** - Response processing utilities:
- `parse_list_to_df()` - Converts nested JSON to tibbles, handling list-columns
- `parse_dates()` - Detects and converts UNIX epoch timestamps
- `update_types()` - Coerces columns based on a dictionary mapping (handles API inconsistencies where the same field returns different types across workouts)

### Type Coercion Dictionary Pattern

The API sometimes returns inconsistent types for the same field across different workouts. Query functions accept a `dictionary` parameter to force column types:

```r
dictionary = list(
  "numeric" = c("column1", "column2"),
  "character" = c("column3"),
  "list" = c("nested_column")
)
```

### Dependencies

Uses tidyverse ecosystem: `httr` for HTTP, `jsonlite` for JSON parsing, `dplyr`/`purrr` for data manipulation, `glue` for string interpolation.
