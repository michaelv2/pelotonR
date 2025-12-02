#' Make a GET request against one of Peloton's API endpoints
#'
#' Users need not invoke this method directly and may instead use one of the wrappers around specific endpoints that also
#' vectorize inputs and process the data returned, such as \code{\link{get_my_info}}, \code{\link{get_performance_graphs}},
#' \code{\link{get_all_workouts}}, \code{\link{get_workout_data}}.
#'
#' Requests are authenticated with a bearer token provided via the \code{PELOTON_BEARER_TOKEN} environment variable. You can
#' add the token to your \code{~/.Renviron} file to make it available in each R session.
#'
#' @export
#' @param path API endpoint to query (include the leading \code{/})
#' @param query Optional named list of query parameters to include
#' @param ... Additional parameters passed on to \code{httr::GET}
#' @examples
#' \dontrun{
#' peloton_api("/api/me")
#' }
peloton_api <- function(path, query = list(), ...) {
  peloton_base <- "https://api.onepeloton.com"

  url <- paste0(peloton_base, path)

  token <- Sys.getenv("PELOTON_BEARER_TOKEN", "")
  if (token == "") {
    stop("PELOTON_BEARER_TOKEN env var not set. Add it to ~/.Renviron.", call. = FALSE)
  }

  res <- httr::GET(
    url,
    query = query,
    httr::add_headers(
      Authorization = paste("Bearer", token),
      `peloton-platform` = "web"
    ),
    ...
  )

  if (httr::status_code(res) >= 300) {
    stop(
      "Peloton GET failed: ",
      httr::status_code(res),
      " for ",
      path,
      "\n",
      httr::content(res, "text", encoding = "UTF-8"),
      call. = FALSE
    )
  }

  jsonlite::fromJSON(httr::content(res, as = "text", encoding = "UTF-8"), simplifyVector = TRUE)
}
