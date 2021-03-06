context("test-build-news.R")

test_that("github links are added to news items", {
  path <- test_path("news-github-links")
  pkg <- as_pkgdown(path)
  news_tbl <- data_news(pkg)

  user_link <- "<a href='http://github.com/hadley'>@hadley</a>"
  issue_link <- "<a href='https://github.com/hadley/pkgdown/issues/100'>#100</a>"

  expect_true(grepl(user_link, news_tbl$html))
  expect_true(grepl(issue_link, news_tbl$html))
})

test_that("build_news() uses content in NEWS.md", {
  pkg <- test_path("news")

  expect_output(build_news(pkg))
  on.exit(clean_site(pkg))

  lines <- read_lines(path(pkg, "docs", "news", "index.html"))
  test_strings <- c("testpackage", "1.0.0.9000", "1.0.0[^\\.]",
                    "sub-heading", "@githubuser", "bullet", "#111")
  expect_true(all(
    vapply(test_strings, function(x) any(grepl(x, lines)), logical(1))
  ))
})
