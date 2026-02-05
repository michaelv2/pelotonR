#' Set up Peloton bearer token interactively
#'
#' Captures your Peloton bearer token by launching a browser and intercepting
#' the \code{Authorization} header from live API requests. Peloton uses Auth0,
#' which stores tokens in memory (not localStorage), so a live browser session
#' is needed.
#'
#' Three methods are available:
#' \describe{
#'   \item{\code{"chromote"}}{(Recommended) Uses the \pkg{chromote} R package to
#'     launch a headed Chrome session and listen for the Authorization header.
#'     Requires \pkg{chromote} and a Chrome/Chromium installation.}
#'   \item{\code{"node"}}{Uses Node.js with Playwright to launch a browser and
#'     capture the token. Requires \code{node} and \code{playwright} to be
#'     installed.}
#'   \item{\code{"manual"}}{Prints instructions for manually copying the token
#'     from browser DevTools, then prompts for the value.}
#' }
#'
#' @param method Character. One of \code{"auto"} (default), \code{"chromote"},
#'   \code{"node"}, or \code{"manual"}. With \code{"auto"}, tries chromote first,
#'   then Node.js, then falls back to manual instructions.
#'
#' @return Invisibly returns \code{TRUE} if the token was successfully saved,
#'   \code{FALSE} otherwise.
#'
#' @export
#' @examples
#' \dontrun{
#' peloton_setup_token()
#' peloton_setup_token(method = "manual")
#' }
peloton_setup_token <- function(method = c("auto", "chromote", "node", "manual")) {
  method <- match.arg(method)

  token <- NULL

  if (method == "auto") {
    token <- setup_token_chromote()
    if (is.null(token)) {
      message("chromote not available, trying Node.js + Playwright...")
      token <- setup_token_node()
    }
    if (is.null(token)) {
      message("Node.js + Playwright not available, falling back to manual instructions.")
      token <- setup_token_manual()
    }
  } else if (method == "chromote") {
    token <- setup_token_chromote()
    if (is.null(token)) {
      message("chromote method failed or is not available.")
      return(invisible(FALSE))
    }
  } else if (method == "node") {
    token <- setup_token_node()
    if (is.null(token)) {
      message("Node.js + Playwright method failed or is not available.")
      return(invisible(FALSE))
    }
  } else {
    token <- setup_token_manual()
  }

  if (is.null(token) || nchar(trimws(token)) == 0) {
    message("No token captured. Setup cancelled.")
    return(invisible(FALSE))
  }

  token <- trimws(token)

  # Strip "Bearer " prefix if user pasted the full header value
  token <- sub("^Bearer\\s+", "", token)

  # Validate JWT format (starts with eyJ which is base64 for {")
  if (!grepl("^eyJ", token)) {
    message("Warning: Token does not appear to be a valid JWT (should start with 'eyJ').")
    proceed <- readline(prompt = "Continue anyway? (y/n): ")
    if (!tolower(trimws(proceed)) %in% c("y", "yes")) {
      message("Setup cancelled.")
      return(invisible(FALSE))
    }
  }

  save_token(token)
}

#' Capture token via chromote (Method 1)
#' @noRd
setup_token_chromote <- function() {
  if (!requireNamespace("chromote", quietly = TRUE)) {
    return(NULL)
  }

  b <- tryCatch(
    chromote::ChromoteSession$new(headless = FALSE),
    error = function(e) {
      message("Could not launch Chrome: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(b)) return(NULL)

  token <- NULL

  b$Network$enable()

  disable <- b$Network$requestWillBeSentExtraInfo(callback_ = function(msg) {
    headers <- msg$headers
    auth <- headers$Authorization %||% headers$authorization
    if (!is.null(auth) && grepl("^Bearer eyJ", auth)) {
      token <<- sub("^Bearer ", "", auth)
    }
  })

  b$Page$navigate(url = "https://members.onepeloton.com")
  cat("\n")
  cat("Browser opened to members.onepeloton.com.\n")
  cat("Please log in to Peloton. The token will be captured automatically.\n")
  cat("Waiting up to 2 minutes...\n")
  cat("\n")

  for (i in seq_len(240)) {
    if (!is.null(token)) break
    Sys.sleep(0.5)
  }

  tryCatch(disable(), error = function(e) NULL)
  tryCatch(b$close(), error = function(e) NULL)

  if (is.null(token)) {
    message("Timed out waiting for token. No Authorization header was captured.")
  } else {
    cat("Token captured successfully!\n")
  }

  token
}

#' Capture token via Node.js + Playwright (Method 2)
#' @noRd
setup_token_node <- function() {
  node <- Sys.which("node")
  if (node == "") return(NULL)

  script <- tempfile(fileext = ".mjs")
  on.exit(unlink(script), add = TRUE)

  writeLines(c(
    "import { chromium } from 'playwright';",
    "",
    "const browser = await chromium.launch({ headless: false });",
    "const context = await browser.newContext();",
    "const page = await context.newPage();",
    "",
    "let token = null;",
    "",
    "page.on('request', request => {",
    "  const auth = request.headers()['authorization'];",
    "  if (auth && auth.startsWith('Bearer eyJ')) {",
    "    token = auth.replace('Bearer ', '');",
    "  }",
    "});",
    "",
    "await page.goto('https://members.onepeloton.com');",
    "process.stderr.write('Browser opened. Please log in to Peloton...\\n');",
    "",
    "const start = Date.now();",
    "while (!token && Date.now() - start < 120000) {",
    "  await new Promise(r => setTimeout(r, 500));",
    "}",
    "",
    "await browser.close();",
    "",
    "if (token) {",
    "  process.stdout.write('TOKEN:' + token);",
    "} else {",
    "  process.stderr.write('Timed out waiting for token.\\n');",
    "  process.exit(1);",
    "}"
  ), script)

  cat("\n")
  cat("Launching browser via Node.js + Playwright...\n")
  cat("Please log in to Peloton. The token will be captured automatically.\n")
  cat("Waiting up to 2 minutes...\n")
  cat("\n")

  result <- tryCatch(
    system2(node, script, stdout = TRUE, stderr = "", timeout = 150),
    error = function(e) NULL,
    warning = function(w) NULL
  )

  if (is.null(result)) return(NULL)

  # Find the line containing the token
  token_line <- grep("^TOKEN:", result, value = TRUE)
  if (length(token_line) == 0) return(NULL)

  token <- sub("^TOKEN:", "", token_line[1])
  if (nchar(token) > 0) {
    cat("Token captured successfully!\n")
    token
  } else {
    NULL
  }
}

#' Manual token extraction (Method 3)
#' @noRd
setup_token_manual <- function() {
  cli_line <- function(...) cat(..., "\n", sep = "")

  cli_line()
  cli_line("=== Peloton Bearer Token Setup (Manual) ===")
  cli_line()
  cli_line("Peloton now uses Auth0, which stores tokens in memory.")
  cli_line("You need to copy the token from the browser's Network tab.")
  cli_line()
  cli_line("Steps:")
  cli_line("------")
  cli_line("1. Open https://members.onepeloton.com and log in")
  cli_line("2. Open Dev Tools (F12 or Cmd+Option+I) -> Network tab")
  cli_line("3. Filter requests to 'api.onepeloton.com'")
  cli_line("4. Click around the page to trigger some API requests")
  cli_line("5. Click any request to api.onepeloton.com")
  cli_line("6. In the Request Headers, find 'Authorization: Bearer eyJ...'")
  cli_line("7. Copy only the token part (the long string starting with 'eyJ')")
  cli_line()

  utils::browseURL("https://members.onepeloton.com")

  token <- readline(prompt = "Paste your token here: ")
  token <- trimws(token)

  if (nchar(token) == 0) return(NULL)
  token
}

#' Save token to ~/.Renviron and load into session
#' @noRd
save_token <- function(token) {
  renviron_path <- path.expand("~/.Renviron")
  env_line <- paste0("PELOTON_BEARER_TOKEN=", token)

  if (file.exists(renviron_path)) {
    existing <- readLines(renviron_path, warn = FALSE)
    existing <- existing[!grepl("^PELOTON_BEARER_TOKEN=", existing)]
    if (length(existing) > 0 && existing[length(existing)] != "") {
      existing <- c(existing, "")
    }
    writeLines(c(existing, env_line), renviron_path)
  } else {
    writeLines(env_line, renviron_path)
  }

  readRenviron(renviron_path)

  cat("\n")
  cat("Token saved to ~/.Renviron and loaded into current session.\n")
  cat("Verify with: Sys.getenv('PELOTON_BEARER_TOKEN')\n")
  cat("\n")

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
