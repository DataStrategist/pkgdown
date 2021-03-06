# Renders LICENSE text file into html
build_home_license <- function(pkg) {
  license_md <- path(pkg$src_path, "LICENSE.md")
  if (file_exists(license_md)) {
    render_md(pkg, license_md)
    return()
  }

  license_raw <- path(pkg$src_path, "LICENSE")
  if (file_exists(license_raw)) {
    render_page(pkg, "title-body",
      data = list(
        pagetitle = "License",
        body = paste0("<pre>", escape_html(read_file(license_raw)), "</pre>")
      ),
      path = "LICENSE.html"
    )
    return()
  }

}

data_home_sidebar_license <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)



  paste0(
    "<h2>License</h2>\n",
    "<p>", autolink_license(pkg$desc$get("License")[[1]]), "</p>\n"
  )
}

# helpers -----------------------------------------------------------------

autolink_license <- function(x) {
  db <- licenses_db()

  for (i in seq_len(nrow(db))) {
    match <- paste0("\\b\\Q", db$abbr[[i]], "\\E\\b")
    x <- gsub(match, db$a[[i]], x, perl = TRUE)
  }
  x
}

licenses_db <- function() {
  path <- path(R.home("share"), "licenses", "license.db")
  db <- tibble::as_tibble(read.dcf(path))

  abbr <- ifelse(is.na(db$SSS), db$Abbrev, db$SSS)
  url <- db$URL

  # Add entry for LICENSE file
  abbr <- c(abbr, "LICENSE")
  url <- c(url, "LICENSE.html")

  out <- tibble::tibble(abbr, url)
  out$a <- paste0("<a href='", url, "'>", abbr, "</a>")

  out[!is.na(out$abbr), ]
}
