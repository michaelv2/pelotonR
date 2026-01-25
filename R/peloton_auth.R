#' Set up Peloton bearer token interactively
#'
#' Opens the Peloton website and guides the user through extracting their
#' bearer token. The token is saved to \code{~/.Renviron} and loaded into
#' the current session.
#'
#' @param open_browser Logical. If \code{TRUE} (the default), opens the Peloton
#'   website in the default browser.
#'
#' @return Invisibly returns \code{TRUE} if the token was successfully saved,
#'   \code{FALSE} otherwise.
#'
#' @export
#' @examples
#' \dontrun{
#' peloton_setup_token()
#' }
peloton_setup_token <- function(open_browser = TRUE) {
  if (open_browser) {
    utils::browseURL("https://members.onepeloton.com")
  }

  # Bookmarklet that checks localStorage for JWT tokens
  bookmarklet <- paste0(
    "javascript:(function(){",
    "for(var k in localStorage){",
    "var v=localStorage[k];",
    "if(typeof v==='string'&&v.indexOf('eyJ')===0){",
    "prompt('Found token in localStorage[\"'+k+'\"]\\n\\nCopy this:',v);return;}",
    "try{var p=JSON.parse(v);for(var k2 in p){",
    "if(typeof p[k2]==='string'&&p[k2].indexOf('eyJ')===0){",
    "prompt('Found in localStorage[\"'+k+'\"].'+k2+'\\n\\nCopy this:',p[k2]);return;}",
    "}}catch(e){}}",
    "alert('No token found');",
    "})()"
  )

  cli_line <- function(...) cat(..., "\n", sep = "")

  cli_line()
  cli_line("=== Peloton Bearer Token Setup ===")
  cli_line()
  cli_line("A browser window should have opened to members.onepeloton.com.")
  cli_line("If not, navigate there manually and log in.")
  cli_line()
  cli_line("OPTION 1: Bookmarklet (quick)")
  cli_line("------------------------------")
  cli_line("Create a bookmark with this URL, then click it on the Peloton page:")
  cli_line()
  cli_line(bookmarklet)
  cli_line()
  cli_line("OPTION 2: Developer Tools (if bookmarklet doesn't find token)")
  cli_line("---------------------------------------------------------------")
  cli_line("1. Open Dev Tools (F12 or Cmd+Option+I) -> Network tab")
  cli_line("2. Click around the page to trigger some requests")
  cli_line("3. Filter by 'api' and click any request")
  cli_line("4. In Request Headers, find 'Authorization: Bearer eyJ...'")
  cli_line("5. Copy only the token part (starts with 'eyJ')")
  cli_line()

  token <- readline(prompt = "Paste your token here: ")
  token <- trimws(token)

  if (nchar(token) == 0) {
    message("No token provided. Setup cancelled.")
    return(invisible(FALSE))
  }

  # Validate JWT format (starts with eyJ which is base64 for {"
  if (!grepl("^eyJ", token)) {
    message("Warning: Token does not appear to be a valid JWT (should start with 'eyJ').")
    proceed <- readline(prompt = "Continue anyway? (y/n): ")
    if (!tolower(trimws(proceed)) %in% c("y", "yes")) {
      message("Setup cancelled.")
      return(invisible(FALSE))
    }
  }

  # Write to ~/.Renviron
  renviron_path <- path.expand("~/.Renviron")
  env_line <- paste0("PELOTON_BEARER_TOKEN=", token)

  # Read existing content if file exists
  if (file.exists(renviron_path)) {
    existing <- readLines(renviron_path, warn = FALSE)
    # Remove any existing PELOTON_BEARER_TOKEN lines
    existing <- existing[!grepl("^PELOTON_BEARER_TOKEN=", existing)]
    # Ensure file ends with newline before appending
    if (length(existing) > 0 && existing[length(existing)] != "") {
      existing <- c(existing, "")
    }
    writeLines(c(existing, env_line), renviron_path)
  } else {
    writeLines(env_line, renviron_path)
  }

  # Reload environment
  readRenviron(renviron_path)

  cli_line()
  cli_line("Token saved to ~/.Renviron and loaded into current session.")
  cli_line("You can verify with: Sys.getenv('PELOTON_BEARER_TOKEN')")
  cli_line()

  invisible(TRUE)
}

#' Deprecated Peloton authentication helper
#'
#' @export
#' @keywords internal
#' @param ... Ignored. Authentication now relies on the \code{PELOTON_BEARER_TOKEN} environment variable.
peloton_auth <- function(...) {
  .Deprecated(
    new = "peloton_setup_token",
    msg = paste(
      "`peloton_auth()` is deprecated.",
      "Use `peloton_setup_token()` to set up your bearer token interactively,",
      "or manually set the PELOTON_BEARER_TOKEN environment variable in ~/.Renviron."
    )
  )
  invisible(NULL)
}
