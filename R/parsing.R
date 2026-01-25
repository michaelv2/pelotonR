#' Parse the \code{JSON} content of a response and turn the result into a \code{tibble} .
#'
#'
#' A helper, agnostic function to parse the content of API responses made to Peloton's API. Leaves most datatypes alone, but converts nested lists into list-columns.
#'
#' @export
#' @param my_list The JSON content of a response (aka a named list in R)
#' @param date_parsing Whether to turn epoch timestamps into datetimes
#' @param dictionary A named list mapping data types to column names for type coercion
#' @examples
#' \dontrun{
#' parse_list_to_df(peloton_api("api/me")$content)
#' }
#'
parse_list_to_df <- function(my_list, date_parsing, dictionary) {
  # Guard against NULL or empty input
  if (is.null(my_list) || length(my_list) == 0) {
    return(tibble::tibble())
  }

  my_names <- names(my_list)

  # Skip unnamed lists - they can't be combined meaningfully with named data
  if (is.null(my_names) || all(my_names == "")) {
    return(tibble::tibble())
  }

  # Ensure all names are character and handle partial naming
  my_names <- as.character(my_names)
  # Filter out elements with empty names
  valid_idx <- my_names != "" & !is.na(my_names)
  my_list <- my_list[valid_idx]
  my_names <- my_names[valid_idx]

  if (length(my_names) == 0) {
    return(tibble::tibble())
  }

  m <- stats::setNames(dplyr::as_tibble(as.data.frame(matrix(nrow = 1L, ncol = length(my_names)))), my_names)
  for (column in seq_along(my_names)) {
    val <- my_list[[column]]
    if (is.null(val) || length(val) == 0) {
      val <- NA_character_
    } else if (is.list(val) || length(val) > 1) {
      # Wrap lists and multi-element vectors as list-columns
      val <- list(val)
    }
    m[[column]] <- val
  }
  if (date_parsing) m <- parse_dates(m)
  if (!is.null(dictionary)) m <- update_types(m, dictionary)
  m
}


#' Convert UNIX epoch timestamps to datetime
#'
#'
#' Helper function convert UNIX timestamps to datestamps. By default converts to \code{America/Los_Angeles} timezone.
#'
#' @export
#' @param dataframe A dataframe containing some columns that may be dates
#' @param tz Timezone to convert datestamp to
#' @examples
#' \dontrun{
#' parse_dates(data.frame(a = 1570914652, b = "adad", c = 123L))
#' }
#'
parse_dates <- function(dataframe, tz = base::Sys.timezone()) {
  exclude_ <- c("peloton_id", "id", "facebook_id", "home_peloton_id")
  fn <- function(x, ...) {
    as.POSIXct(x, origin = "1970-01-01", tz)
  }
  col_names <- names(dataframe)
  true <- logical(length = length(col_names))
  for (i in seq_along(col_names)) {
    name <- col_names[i]
    # TODO parse inner list too
    true[[i]] <- grepl(pattern = "^1[0-9]{9}", x = dataframe[[name]]) && !is.list(dataframe[[name]]) && !name %in% exclude_
  }
  vars <- col_names[true]
  if (length(vars) == 0) {
    return(dataframe)
  }
  dplyr::mutate(dataframe, dplyr::across(dplyr::all_of(vars), fn))
}


#' Update data types after parsing to dataframe
#'
#'
#' Modify inconsistent data types
#'
#' @export
#' @param df the output of parse_list_to_df
#' @param dictionary dictionary to interpret
#' @examples
#' \dontrun{
#' df <- dplyr::tibble(
#'   z = c("1", "2", "3"),
#'   x = c(9, 8, 7), f = "a"
#' )
#' dictionary <- list(
#'   "numeric" = c("x", "z"),
#'   "character" = c("m", "f")
#' )
#' update_types(df, dictionary)
#' }
#'
update_types <- function(df, dictionary = NULL) {
  if (!is.null(dictionary)) {
    included_types <- c("numeric", "character", "list")
    if (!all(names(dictionary) %in% c(included_types))) stop("The provided dictionary can only include one of the following types: `numeric`, `character`, or `list`", call. = FALSE)
    for (g in seq_along(dictionary)) {
      cols <- dictionary[[g]]
      # loop across types
      for (i in seq_along(cols)) {
        # ensure column exists in df
        if (cols[[i]] %in% colnames(df)) {
          # extract type
          type_convert <- names(dictionary[g])
          # convert types
          if (type_convert == "numeric") {
            df[[cols[[i]]]] <- as.numeric(df[[cols[[i]]]])
          } else if (type_convert == "character") {
            df[[cols[[i]]]] <- as.character(df[[cols[[i]]]])
          } else if (type_convert == "list") {
            df[[cols[[i]]]] <- list(df[[cols[[i]]]])
          }
        }
      }
    }
    df
  } else {
    df
  }
}
