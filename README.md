# pelotonR

<!-- badges: start -->

[![Lifecycle: maturing](https://img.shields.io/badge/lifecycle-maturing-blue.svg)](https://www.tidyverse.org/lifecycle/#maturing)

<!-- badges: end -->

`pelotonR` provides an `R` interface into the Peloton data API. The package handles authentication, response parsing, and provides helper functions to find and extract data from the most important endpoints.

## Installation

Currently on [Github](https://github.com/bweiher/pelotonR) only. Install with:

``` r
devtools::install_github("bweiher/pelotonR")
```

## Quick Setup

The easiest way to configure authentication is with the interactive setup helper:

``` r
library(pelotonR)
peloton_setup_token()
```

This will:
1. Open the Peloton website in your browser
2. Provide a bookmarklet to extract your token from localStorage
3. Save the token to `~/.Renviron` automatically
4. Load the token into your current R session

## Overview

#### **Authentication**

Set the `PELOTON_BEARER_TOKEN` environment variable. Adding it to your `~/.Renviron` file will make it available in each R session. No login helper is required once the token is present.

<details>
<summary>Manual setup instructions (click to expand)</summary>

To locate your bearer token manually, from a browser:

1. Log in at https://members.onepeloton.com.
2. Open Dev Tools -> **Network** tab
3. Filter by `api.me` and select one of the requests that returned `200`.
5. In the **Request Headers** section, find `Authorization: Bearer eyJ...`.
6. Copy **only** the token part after `Bearer` (the long `eyJ...` string).
7. Put that in your `~/.Renviron` as e.g.: `PELOTON_BEARER_TOKEN=eyJ...long_token_here...`
8. Then reload in R: `readRenviron("~/.Renviron")`
9. This may need to be reloaded periodically whenever Peloton expires it.

<img width="600" height="198" alt="image" src="https://github.com/user-attachments/assets/0d959d49-cea5-4fb6-8c28-37249bbfdcff" />

</details>

#### Data Available

The main endpoints each have their own helper function that helps parse the API response into a `tibble`, as well as iterating through multiple inputs if necessary.

You can also query other endpoints using `peloton_api` in case new endpoints are introduced, or if the automatic parsing fails (can also set p.

The table below documents each endpoint along with its `R` counterpart, and provides a description of what data is there:

| endpoint                                 | function                   | endpoint description                     |
|------------------------------------------|----------------------------|------------------------------------------|
| api/me                                   | `get_my_info()`            | info about you                           |
| api/workout/workout_id/performance_graph | `get_performance_graphs()` | time series metrics for individual rides |
| api/workout/workout_id                   | `get_workout_data()`       | data about rides                         |
| api/user/user_id/workouts                | `get_all_workouts()`       | lists workouts with automatic pagination |

You can inspect helper logic directly in the package if you want to see which endpoints and query parameters are being called under the hood.

#### Queries

Most functions automatically fetch the required user ID, so you can get started right away:

``` r
# get a list of your workouts (user ID auto-fetched)
workouts <- get_all_workouts()
workout_ids <- workouts$id

# limit to 10 workouts
workouts <- get_all_workouts(num_workouts = 10)

# include ride and instructor data
workouts <- get_all_workouts(joins = "ride,ride.instructor")
```

The final two endpoints contain your performance graphs and other workout data. You need to provide `workout_id`'s here, but each function accepts multiple at once:

``` r
# get performance graph data
# vectorized function
pg <- get_performance_graphs(workout_ids) # peloton_api("api/workout/$WORKOUT_ID/performance_graph")

# get other workout data
# vectorized function

wd <- get_workout_data(workout_id = workout_ids[1])
```

------------------------------------------------------------------------

#### Handling Type Inconsistencies

The Peloton API occasionally returns inconsistent types for the same field across different workouts. For example, a field might be an integer in one response and a character in another.

`get_all_workouts()` handles this automatically using `bind_rows()`.

For `get_workout_data()` and `get_performance_graphs()`, you can use the `dictionary` parameter to force column types if you encounter errors like:

    #> Error: Can't combine `..1$some_column` <integer> and `..10$some_column` <character>.

``` r
# Force specific columns to a type
wd <- get_workout_data(
  workout_id = workout_ids,
  dictionary = list(
    "numeric" = c("some_column"),
    "character" = c("another_column"),
    "list" = c("nested_column")
  )
)
```
