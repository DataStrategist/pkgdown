#' Build articles
#'
#' Each Rmarkdown vignette in `vignettes/` and its subdirectories is
#' rendered. Vignettes are rendered using a special document format that
#' reconciles [rmarkdown::html_document()] with your pkgdown
#' template.
#'
#' @section YAML config:
#' To tweak the index page, you need a section called `articles`,
#' which provides a list of sections containing, a `title`, list of
#' `contents`, and optional `description`.
#'
#' For example, this imaginary file describes some of the structure of
#' the \href{http://rmarkdown.rstudio.com/articles.html}{R markdown articles}:
#'
#' \preformatted{
#' articles:
#' - title: R Markdown
#'   contents:
#'   - starts_with("authoring")
#' - title: Websites
#'   contents:
#'   - rmarkdown_websites
#'   - rmarkdown_site_generators
#' }
#'
#' Note that `contents` can contain either a list of vignette names
#' (including subdirectories), or if the functions in a section share a
#' common prefix or suffix, you can use `starts_with("prefix")` and
#' `ends_with("suffix")` to select them all. If you don't care about
#' position within the string, use `contains("word")`. For more complex
#' naming schemes you can use an aribrary regular expression with
#' `matches("regexp")`.
#'
#' pkgdown will check that all vignettes are included in the index
#' this page, and will generate a warning if you have missed any.
#'
#' @section Supressing vignettes:
#'
#' If you want articles that are not vignettes, either put them in
#' subdirectories or list in `.Rbuildignore`. An articles link
#' will be automatically added to the default navbar if the vignettes
#' directory is present: if you do not want this, you will need to
#' customise the navbar. See [build_site()] details.
#'
#' @param pkg Path to source package. If R working directory is not
#'     set to the source directory, then pkg must be a fully qualified
#'     path to the source directory (not a relative path).
#' @param quiet Set to `FALSE` to display output of knitr and
#'   pandoc. This is useful when debugging.
#' @param preview If `TRUE`, or `is.na(preview) && interactive()`, will preview
#'   freshly generated section in browser.
#' @export
build_articles <- function(pkg = ".",
                           quiet = TRUE,
                           preview = NA) {
  pkg <- section_init(pkg, depth = 1L)

  if (nrow(pkg$vignettes) == 0L) {
    return(invisible())
  }

  rule("Building articles")
  dir_create(path(pkg$dst_path, "articles"))

  # copy everything from vignettes/ to docs/articles
  copy_dir(
    path(pkg$src_path, "vignettes"),
    path(pkg$dst_path, "articles"),
    exclude_matching = "rsconnect"
  )

  # Render each Rmd then delete them
  articles <- tibble::tibble(
    input = path(pkg$dst_path, "articles", pkg$vignettes$file_in),
    output_file = pkg$vignettes$file_out,
    depth = pkg$vignettes$vig_depth + 1L
  )
  data <- list(
    pagetitle = "$title$",
    opengraph = list(description = "$description$")
  )
  purrr::pwalk(articles, render_rmd,
    pkg = pkg,
    data = data,
    quiet = quiet
  )

  file_delete(articles$input)

  build_articles_index(pkg)

  section_fin(pkg, "articles", preview = preview)
}

render_rmd <- function(pkg,
                       input,
                       output_file,
                       depth = 0L,
                       strip_header = FALSE,
                       data = list(),
                       toc = TRUE,
                       quiet = TRUE) {

  cat_line("Building article '", output_file, "'")
  scoped_package_context(pkg$package, pkg$topic_index, pkg$article_index)
  scoped_file_context(depth = depth)

  format <- build_rmarkdown_format(pkg, depth = depth, data = data, toc = toc)
  on.exit(file_delete(format$path), add = TRUE)

  path <- callr::r_safe(
    function(...) rmarkdown::render(...),
    args = list(
      input,
      output_format = format$format,
      output_file = basename(output_file),
      quiet = quiet,
      encoding = "UTF-8",
      envir = globalenv()
    ),
    show = !quiet
  )
  update_rmarkdown_html(path, strip_header = strip_header)
}

build_rmarkdown_format <- function(pkg = ".",
                                   depth = 1L,
                                   data = list(),
                                   toc = TRUE) {
  # Render vignette template to temporary file
  path <- tempfile(fileext = ".html")
  render_page(pkg, "vignette", data, path, depth = depth, quiet = TRUE)

  list(
    path = path,
    format = rmarkdown::html_document(
      toc = toc,
      toc_depth = 2,
      self_contained = FALSE,
      theme = NULL,
      template = path
    )
  )
}

update_rmarkdown_html <- function(path, strip_header = FALSE) {
  html <- xml2::read_html(path, encoding = "UTF-8")
  tweak_rmarkdown_html(html, strip_header = strip_header)

  xml2::write_html(html, path, format = FALSE)
  path
}

# Articles index ----------------------------------------------------------

build_articles_index <- function(pkg = ".") {
  render_page(
    pkg,
    "vignette-index",
    data = data_articles_index(pkg),
    path = path("articles", "index.html")
  )
}

data_articles_index <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  meta <- pkg$meta$articles %||% default_articles_index(pkg)
  sections <- meta %>%
    purrr::map(data_articles_index_section, pkg = pkg) %>%
    purrr::compact()

  # Check for unlisted vignettes
  listed <- sections %>%
    purrr::map("contents") %>%
    purrr::map(. %>% purrr::map_chr("name")) %>%
    purrr::flatten_chr() %>%
    unique()
  missing <- !(pkg$vignettes$name %in% listed)

  if (any(missing)) {
    warning(
      "Vignettes missing from index: ",
      paste(pkg$vignettes$name[missing], collapse = ", "),
      call. =  FALSE,
      immediate. = TRUE
    )
  }

  print_yaml(list(
    pagetitle = "Articles",
    sections = sections
  ))
}

data_articles_index_section <- function(section, pkg) {
  if (!set_contains(names(section), c("title", "contents"))) {
    warning(
      "Section must have components `title`, `contents`",
      call. = FALSE,
      immediate. = TRUE
    )
    return(NULL)
  }

  # Match topics against any aliases
  in_section <- select_vignettes(section$contents, pkg$vignettes)
  section_vignettes <- pkg$vignettes[in_section, ]
  contents <- tibble::tibble(
    name = section_vignettes$name,
    path = section_vignettes$file_out,
    title = section_vignettes$title
  )

  list(
    title = section$title,
    desc = markdown_text(section$desc),
    class = section$class,
    contents = purrr::transpose(contents)
  )
}

# Quick hack: create the same structure as for topics so we can use
# the existing select_topics()
select_vignettes <- function(match_strings, vignettes) {
  topics <- tibble::tibble(
    name = vignettes$name,
    alias = as.list(vignettes$name),
    internal = FALSE
  )
  select_topics(match_strings, topics)
}

default_articles_index <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  print_yaml(list(
    list(
      title = "All vignettes",
      desc = NULL,
      contents = paste0("`", pkg$vignettes$name, "`")
    )
  ))

}
