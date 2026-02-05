#' Makes a request against the \code{api/me} endpoint
#'
#'
#' Returns user metadata, including userid, email, account status, etc.  \code{userid} is particularly useful since you need it for \code{\link{get_workout_data}}.
#'
#' @export
#' @param dictionary A named list mapping data types to column names for type coercion. If \code{NULL} (default), no type coercion is done.
#' @param date_parsing Whether to try and guess which columns are dates and convert (default \code{TRUE})
#' @param ... Other arguments passed on to methods
#' @examples
#' \dontrun{
#' get_my_info()
#' }
#'
get_my_info <- function(dictionary = NULL, date_parsing = TRUE, ...) {
  resp <- peloton_api("/api/me", ...)
  resp
}


#' Makes a call to \code{\link{get_my_info}}
#'
#'
#' Returns \code{userid}.
#'
#' @export
#' @param ... Other arguments passed on to methods
#' @examples
#' \dontrun{
#' peloton_user_id()
#' }
#'
peloton_user_id <- function(...) {
  get_my_info()$id
}


#' Makes a request against the \code{api/workout/workout_id/performance_graph} endpoint
#'
#'
#' For each workout, returns time series of individual workouts capturing cadence, output, resistance, speed, heart-rate (if applicable), measured at second intervals defined by \code{every_n}. A vectorized function, so accepts multiple \code{workoutIDs} at once.
#'
#' @export
#' @importFrom rlang .data
#' @param workout_ids WorkoutIDs
#' @param every_n How often measurements are reported. If set to 1, there will be 60 data points per minute of a workout
#' @param dictionary A named list. Maps a data-type to a column name. If \code{NULL} then no parsing is done
#' @param date_parsing Whether to try and guess which columns are dates and convert
#' @param ... Other arguments passed on to methods
#' @examples
#' \dontrun{
#' workouts <- get_all_workouts()
#' get_performance_graphs(workouts$id)
#' get_performance_graphs(workouts$id,
#'   dictionary =
#'     list("list" = c("seconds_since_pedaling_start", "segment_list"))
#' )
#' }
#'
get_performance_graphs <- function(workout_ids, every_n = 5, dictionary = list("list" = c("seconds_since_pedaling_start", "segment_list")), date_parsing = TRUE, ...) {
  purrr::map(workout_ids, function(workout_id) {
    resp <- peloton_api(
      path = glue::glue("/api/workout/{workout_id}/performance_graph"),
      query = list(
        every_n = every_n
      ),
      ...
    )

    parse_list_to_df(resp, dictionary = dictionary, date_parsing = date_parsing) |>
      dplyr::mutate(
        id = workout_id
      )
  }) |>
    purrr::list_rbind()
}


#' Makes a request against the \code{api/user_id/workouts/} endpoint
#'
#'
#' Fetches workouts for a user with automatic pagination support.
#' Combines the best of the original \code{get_all_workouts()} and
#' \code{get_all_workouts2()} functions.
#'
#' @export
#' @param userid User ID. If \code{NULL} (default), automatically fetches via \code{\link{peloton_user_id}}.
#' @param num_workouts Maximum number of workouts to fetch. Use \code{Inf} (default) to fetch all.
#' @param joins Additional joins to make on the data (e.g. \code{"ride"} or \code{"ride,ride.instructor"}).
#'   Results in additional columns being added to the data.frame with \code{ride_} prefix.
#' @param limit_per_page Number of workouts to fetch per API request (default 100).
#' @examples
#' \dontrun{
#' # Fetch all workouts (auto-fetches user ID)
#' get_all_workouts()
#'
#' # Fetch only 10 workouts
#' get_all_workouts(num_workouts = 10)
#'
#' # Include ride and instructor data
#' get_all_workouts(joins = "ride,ride.instructor")
#'
#' # Specify user ID explicitly
#' get_all_workouts(userid = "your_user_id")
#' }
#'
get_all_workouts <- function(
    userid = NULL,
    num_workouts = Inf,
    joins = "",
    limit_per_page = 100
) {
  # Auto-fetch userid if not provided
  if (is.null(userid) || userid == "") {
    userid <- peloton_user_id()
  }

  # Validate userid is not empty
  if (is.null(userid) || userid == "") {
    stop("userid is empty. Provide a userid or ensure peloton_user_id() returns a valid ID.", call. = FALSE)
  }

  # Validation
  if (length(joins) > 1 || !is.character(joins)) {
    stop("Provide joins as a length one character vector", call. = FALSE)
  }

  # Build query with joins support
  workout_query <- list(limit = limit_per_page, page = 0L)
  if (joins != "") workout_query$joins <- joins

  # Pagination loop
  all_items <- list()
  page <- 0L
  total_fetched <- 0L

  repeat {
    page <- page + 1L
    workout_query$page <- page

    resp <- peloton_api(
      paste0("/api/user/", userid, "/workouts"),
      query = workout_query
    )

    items <- resp$data
    if (length(items) == 0) break

    all_items[[length(all_items) + 1L]] <- items
    total_fetched <- total_fetched + length(items)

    if (!is.null(resp$page_count) && page >= resp$page_count) break
    if (total_fetched >= num_workouts) break
  }

  if (length(all_items) == 0) return(tibble::tibble())

  # Simple bind_rows parsing
  workouts <- dplyr::bind_rows(all_items)

  # Parse known date columns
  date_cols <- intersect(c("start_time", "end_time", "created_at"), names(workouts))
  for (col in date_cols) {
    workouts[[col]] <- lubridate::as_datetime(workouts[[col]])
  }

  # Handle joins - extract and merge ride data
  if (joins != "" && "ride" %in% names(workouts)) {
    rides <- dplyr::bind_rows(workouts$ride)
    names(rides) <- paste0("ride_", names(rides))
    workouts <- dplyr::bind_cols(
      dplyr::select(workouts, -"ride"),
      rides
    )
  }

  # Trim to requested number
  if (is.finite(num_workouts) && nrow(workouts) > num_workouts) {
    workouts <- workouts[seq_len(num_workouts), ]
  }

  workouts
}


#' Deprecated: Use \code{\link{get_all_workouts}} instead
#'
#' This function is deprecated. Use \code{\link{get_all_workouts}} which now
#' includes all the features of \code{get_all_workouts2()} including automatic
#' pagination and user ID auto-fetch.
#'
#' @export
#' @param limit_per_page Number of workouts to fetch per API request (default 100)
#' @param max_pages Maximum number of pages to fetch. Use \code{Inf} (default) to fetch all workouts.
#' @param joins Additional joins (e.g., "ride,ride.instructor")
#' @examples
#' \dontrun{
#' # Use get_all_workouts() instead
#' get_all_workouts()
#' }
#'
get_all_workouts2 <- function(limit_per_page = 100, max_pages = Inf, joins = "") {
  .Deprecated("get_all_workouts")
  get_all_workouts(
    userid = NULL,
    num_workouts = max_pages * limit_per_page,
    joins = joins,
    limit_per_page = limit_per_page
  )
}


#' Makes a request against the \code{api/workout/workout_id} endpoint
#'
#'
#' Returns data about individual workouts. A vectorized function, so accepts multiple \code{workoutIDs} at once.
#'
#' @export
#' @param workout_id WorkoutID
#' @param dictionary A named list. Maps a data-type to a column name. If \code{NULL} then no parsing is done
#' @param date_parsing Whether to try and guess which columns are dates and convert
#' @examples
#' \dontrun{
#' get_workout_data(
#'   workout_id = workout_id,
#'   dictionary = list(
#'     "numeric" = c(
#'       "v2_total_video_watch_time_seconds", "v2_total_video_buffering_seconds",
#'       "v2_total_video_watch_time_seconds", "leaderboard_rank"
#'     ),
#'     "list" = c("achievement_templates")
#'   )
#' )
#' }
get_workout_data <- function(workout_id, date_parsing = TRUE, dictionary = list(
  "numeric" = c(
    "v2_total_video_watch_time_seconds", "v2_total_video_buffering_seconds", "leaderboard_rank"
  ),
  "list" = c("achievement_templates")
)) {
  
  dat <- peloton_api(
    paste0("/api/workout/", workout_id)
  )
  
  parse_list_to_df(my_list = dat, dictionary = dictionary, date_parsing = date_parsing)
}


#' Get performance summary for workouts
#'
#'
#' Extracts summary statistics from the performance_graph endpoint including
#' duration, summaries (totals like Distance, Calories), average summaries
#' (like Avg Pace, Avg Cadence), effort zones, and metrics. Works for any
#' workout type (cycling, running, rowing, etc.).
#'
#' @export
#' @param workout_ids One or more workout IDs
#' @param ... Additional arguments passed to \code{\link{peloton_api}}
#' @return A tibble with one row per workout containing summary data as list-columns
#' @examples
#' \dontrun{
#' workouts <- get_all_workouts(num_workouts = 5)
#' get_performance_summary(workouts$id)
#' }
#'
get_performance_summary <- function(workout_ids, ...) {
  purrr::map(workout_ids, function(workout_id) {
    resp <- peloton_api(
      path = glue::glue("/api/workout/{workout_id}/performance_graph"),
      query = list(every_n = 1),
      ...
    )

    tibble::tibble(
      id = workout_id,
      duration = if (!is.null(resp$duration)) resp$duration else NA_real_,
      summaries = list(if (!is.null(resp$summaries)) resp$summaries else list()),
      average_summaries = list(if (!is.null(resp$average_summaries)) resp$average_summaries else list()),
      effort_zones = list(if (!is.null(resp$effort_zones)) resp$effort_zones else list()),
      metrics = list(if (!is.null(resp$metrics)) resp$metrics else list())
    )
  }) |>
    purrr::list_rbind()
}


#' Get running-specific workout details
#'
#'
#' A convenience wrapper around \code{\link{get_performance_summary}} that extracts
#' running-relevant metrics: duration (in minutes), distance, pace, max pace,
#' and heart rate zone 4/5 ratios.
#'
#' @export
#' @param workout_ids One or more workout IDs (should be running workouts)
#' @param ... Additional arguments passed to \code{\link{peloton_api}}
#' @return A tibble with columns: \code{id}, \code{duration} (minutes), \code{distance},
#'   \code{pace}, \code{max_pace}, \code{zone4} (ratio), \code{zone5} (ratio)
#' @examples
#' \dontrun{
#' workouts <- get_all_workouts()
#' running <- workouts[workouts$fitness_discipline == "running", ]
#' get_run_details(running$id)
#' }
#'
get_run_details <- function(workout_ids, ...) {
  summary_data <- get_performance_summary(workout_ids, ...)

  purrr::map(seq_len(nrow(summary_data)), function(i) {
    row <- summary_data[i, ]

    tibble::tibble(
      id = row$id,
      duration = row$duration / 60,
      distance = extract_summary_value(row$summaries[[1]], "Distance"),
      pace = extract_average_value(row$average_summaries[[1]], "Avg Pace"),
      max_pace = extract_metric_max(row$metrics[[1]], "Pace"),
      zone4 = extract_zone_ratio(row$effort_zones[[1]], row$duration, 4),
      zone5 = extract_zone_ratio(row$effort_zones[[1]], row$duration, 5)
    )
  }) |>
    purrr::list_rbind()
}


# Internal helpers for extracting values from performance summary data --------

extract_summary_value <- function(summaries, display_name) {
  if (is.null(summaries) || length(summaries) == 0) return(NA_real_)
  if (is.data.frame(summaries)) {
    idx <- which(summaries$display_name == display_name)
    if (length(idx) == 0) return(NA_real_)
    return(as.numeric(summaries$value[idx[1]]))
  }
  NA_real_
}

extract_average_value <- function(averages, display_name) {
  if (is.null(averages) || length(averages) == 0) return(NA_real_)
  if (is.data.frame(averages)) {
    idx <- which(averages$display_name == display_name)
    if (length(idx) == 0) return(NA_real_)
    return(as.numeric(averages$value[idx[1]]))
  }
  NA_real_
}

extract_metric_max <- function(metrics, display_name) {
  if (is.null(metrics) || length(metrics) == 0) return(NA_real_)
  if (is.data.frame(metrics)) {
    idx <- which(metrics$display_name == display_name)
    if (length(idx) == 0) return(NA_real_)
    return(as.numeric(metrics$max_value[idx[1]]))
  }
  NA_real_
}

extract_zone_ratio <- function(effort_zones, duration, zone_num) {
  if (is.null(effort_zones) || length(effort_zones) == 0) return(NA_real_)
  if (is.null(duration) || is.na(duration) || duration == 0) return(NA_real_)
  durations <- effort_zones$heart_rate_zone_durations
  if (is.null(durations)) return(NA_real_)
  zone_key <- paste0("heart_rate_z", zone_num, "_duration")
  zone_val <- durations[[zone_key]]
  if (is.null(zone_val)) return(NA_real_)
  as.numeric(zone_val) / as.numeric(duration)
}
