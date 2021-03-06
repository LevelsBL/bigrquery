base_url <- "https://www.googleapis.com/bigquery/v2/"
upload_url <- "https://www.googleapis.com/upload/bigquery/v2/"

#' @importFrom httr GET config
bq_get <- function(url, config = NULL, ..., token = get_access_cred()) {
  if (is.null(config)) {
    config <- config()
  }
  config <- c(config, token = token)
  req <- GET(paste0(base_url, url), config, ...)
  process_request(req)
}

#' @importFrom httr DELETE config
bq_delete <- function(url, config = NULL, ..., token = get_access_cred()) {
  if (is.null(config)) {
    config <- config()
  }
  config <- c(config, token = token)
  req <- DELETE(paste0(base_url, url), config, ...)
  
  process_request(req)
}

#' @importFrom httr POST add_headers config
bq_post <- function(url, body, config = NULL, ..., token = get_access_cred()) {
  if (is.null(config)) {
    config <- config()
  }
  json <- jsonlite::toJSON(body)
  config <- c(config, token = token, add_headers("Content-type" = "application/json"))

  req <- POST(paste0(base_url, url), config, body = json, ...)
  process_request(req)
}

#' @importFrom httr POST add_headers config
bq_upload <- function(url, parts, config = NULL, ..., token = get_access_cred()) {
  if (is.null(config)) {
    config <- config()
  }
  
  config <- c(config, token = token)
  
  url <- paste0(upload_url, url)
  req <- POST_multipart_related(url, config, parts = parts, ...)
  process_request(req)
}


#' @importFrom httr http_status content parse_media
process_request <- function(req) {
  # No content -> success
  if (req$status_code == 204) return(TRUE)
  
  if (http_status(req)$category == "success") {
    return(content(req, "parsed", "application/json"))
  }

  type <- parse_media(req$headers$`Content-type`)
  if (type$complete == "application/json") {
    out <- content(req, "parsed", "application/json")
    
    if (out$error$code == 401) {
      reset_access_cred()
      stop("Invalid access credentials have been reset. Please try again.",
        call. = FALSE)
    } else {
      stop(out$err$message, call. = FALSE)  
    }
    
  } else {
    out <- content(req, "text")
    stop("HTTP error [", req$status, "] ", out, call. = FALSE)
  }
}

# Multipart/related ------------------------------------------------------------


# http://www.w3.org/Protocols/rfc1341/7_2_Multipart.html
POST_multipart_related <- function(url, config = NULL, parts = NULL, ...,
                                   boundary = random_boundary(), 
                                   handle = NULL) {
  if (is.null(config)) config <- config()
  
  sep <- paste0("\n--", boundary, "\n")
  end <- paste0("\n--", boundary, "--\n")
  
  body <- paste0(sep, paste0(parts, collapse = sep), end)
  
  type <- paste0("multipart/related; boundary=", boundary)
  config <- c(config, add_headers("Content-Type" = type))
  
  POST(url, config = config, body = body, query = list(uploadType = "multipart"), ..., handle = handle)
}

part <- function(headers, body) {
  if (length(headers) == 0) {
    header <- "\n"
  } else {
    header <- paste0(names(headers), ": ", headers, "\n", collapse = "")
  }
  body <- paste0(body, collapse = "\n")
  
  paste0(header, "\n", body)
}

random_boundary <- function() {
  valid <- c(LETTERS, letters, 0:9) # , "'", "(", ")", "+", ",", "-", ".", "/", 
  #  ":", "?")
  paste0(sample(valid, 50, replace = TRUE), collapse = "")
}

