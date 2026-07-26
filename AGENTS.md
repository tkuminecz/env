# General rules

Use simpler and plainer english style of explanation.

Use a GAN-style thinking framework — give me specific critiques and concrete suggestions.

When implementing new features, fixing bugs or problems, prefer red/green TDD.

If some things are not working, work through or surface the issues, don't just skip them as not being important, relevant, or necessary to the main task at hand.

**Don't assume you can't run something.** Always try running tests, servers, or other commands before concluding they won't work. If a command fails, report the actual error — don't preemptively give up.

Generally don't include ticket numbers in code comments unless referring to an upcoming fix (i.e. like a TODO comment).

Don't include changelog-like narrations in comments or documents.

# Web search and fetching

Default to `pplx` (Perplexity CLI) for search — current information, news, docs, "what's the state of X". It returns ranked links fast and costs about half a cent per search.

Reach for firecrawl when the job is reading a page rather than finding one:

- JS-rendered pages and SPAs
- crawling a site or a whole docs section
- structured extraction against a schema
- anything needing clicks, forms, or a logged-in session

`pplx content fetch` handles plain static pages and is far cheaper per page, so try it first for simple reads. If it comes back empty or paywalled, switch to firecrawl scrape.

# Git commits

You should let the user review changes before committing, unless the user has instructed you to eagerly commit.

Use conventional commits.

If a Linear ticket number is available, include it in the commit message, but put it in the body, not the first line. Similarly, you should use the git branch name provided by Linear if possible.

Before committing, make sure to run any available checks for the project, like linter, typechecking, formatting, etc. NEVER force skipping checks in order to commit. It almost always means our change caused a problem or we forget to run `mise run sync`.

Don't typically force push unless necessary. Prefer making new commits when appropriate.

# Opening PRs & Writing PR descriptions

When writing PR description:
- first is a tldr which should be an explanation of problem and solution in plain & simple english
- then a more thorough summary of the changes. the most important thing is WHY the changes are introduced.
- include "how to test" instructions for the reviewer with steps on how they can test the changes in the PR.
- don't include changelog-like narratives

# Commenting on PRs

Whenever replying to comments on PRs, prefix the message indicating that it's an agent responding on behalf of the user. MAKE SURE YOU REFERENCE THE CORRECT GITHUB USER (i.e. tkuminecz). say "> Agent replying on behalf of @tkuminecz"

When replying to a comment, tag who wrote the original comment we are replying to.

If you're replying to a comment with a fix, include the short commit ID that contains the fix. This means you should typically push your commits to the remote before replying.

Don't add replies without showing a draft and confirming with the user.

When you reply to a comment, include a direct link to the reply.

# Writing and running tests

For each test case, you should ALWAYS include a comment explaning what is being tested and the motivation for it.

In general, don't add tests where we're simply constructing an object (esp Pydantic models) and then just asserting that the fields contain what was passed in. Those aren't really valuable.

Never run single tests to validate changes. You can run single tests as a quick check, but must ALWAYS be followed by running the whole suite when finished with changes.
