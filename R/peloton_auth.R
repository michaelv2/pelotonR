#' Deprecated Peloton authentication helper
#'
#' @export
#' @keywords internal
#' @param ... Ignored. Authentication now relies on the \code{PELOTON_BEARER_TOKEN} environment variable.
peloton_auth <- function(...) {
  .Deprecated(msg = paste(
    "`peloton_auth()` is deprecated. Set the PELOTON_BEARER_TOKEN environment variable",
    "in your ~/.Renviron file and use `peloton_api()` or the helper query functions instead."
  ))
  invisible(NULL)
}
