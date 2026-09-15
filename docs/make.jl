using PathCompleteCertificates
using Documenter

DocMeta.setdocmeta!(
    PathCompleteCertificates,
    :DocTestSetup,
    :(using PathCompleteCertificates);
    recursive = true,
)

makedocs(;
    modules = [PathCompleteCertificates],
    sitename = "PathCompleteCertificates.jl",
    authors = "Léa Ninite, Julien Calbert, Raphaël M. Jungers",
    format = Documenter.HTML(;
        canonical = "https://dionysos-dev.github.io/PathCompleteCertificates.jl",
        prettyurls = get(ENV, "CI", "false") == "true",
    ),
    pages = ["Home" => "index.md"],
    # The tool paper has six pages including references, so it cannot explain the
    # package — these docs have to. `checkdocs = :all` makes that enforceable:
    # every exported symbol needs a docstring or the build fails.
    checkdocs = :all,
)

deploydocs(;
    repo = "github.com/dionysos-dev/PathCompleteCertificates.jl",
    devbranch = "master",
    # Previews are cleaned up by .github/workflows/doc-preview-cleanup.yml when
    # the PR closes. Without that they accumulate in gh-pages forever.
    push_preview = true,
)
