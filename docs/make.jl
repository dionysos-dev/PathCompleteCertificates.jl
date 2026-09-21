using PathCompleteCertificates
using Documenter, Literate
import DocumenterCitations

const SRC_DIR = joinpath(@__DIR__, "src")
const EXAMPLES_DIR = joinpath(SRC_DIR, "examples")
const OUTPUT_DIR = joinpath(SRC_DIR, "generated")
const REFERENCE_DIR = joinpath(SRC_DIR, "reference")

# Executing the examples dominates the build -- each solves a sequence of
# semidefinite programs, and two of them draw. Skip it for fast local iteration
# on prose with PCC_SKIP_LITERATE=true; pages whose markdown is not already in
# `src/generated` are then dropped from the nav rather than breaking the build.
const SKIP_LITERATE = get(ENV, "PCC_SKIP_LITERATE", "false") == "true"

# Reading order, roughly "what is a system" through "why the two axes matter".
# Anything not listed here is appended alphabetically with a notice, so adding
# an example is just a file in the folder -- no edit to this file required --
# while the reading order stays curated.
const ORDER = [
    "switched_systems",
    "simulate",
    "stability",
    "safety",
    "safety_barrier",
    "optimal_control",
    "two_axes",
]

function example_stems()
    stems = sort([f[1:(end - 3)] for f in readdir(EXAMPLES_DIR) if endswith(f, ".jl")])
    known = filter(in(stems), ORDER)
    rest = sort(setdiff(stems, known))
    isempty(rest) || @info "docs: examples missing from ORDER -- appended" rest
    stale = setdiff(ORDER, stems)
    isempty(stale) || @warn "docs: ORDER lists files that do not exist" stale
    return vcat(known, rest)
end

# The nav entry is the example's own `# # Title` line. That decouples the
# sidebar text from the URL, so filenames stay lowercase and space-free without
# the nav going with them.
function example_title(path)
    for line in eachline(path)
        matched = match(r"^#\s+#\s+(.*\S)\s*$", line)
        matched === nothing || return String(matched.captures[1])
    end
    return titlecase(replace(basename(path)[1:(end - 3)], '_' => ' '))
end

# Documenter resolves `[`f`](@ref)` against the page's `CurrentModule`, and a
# generated page has no way to set that for itself -- without this, every
# docstring reference in an example resolves against `Main` and fails. Literate
# already emits a `@meta` block for `EditURL`, so join it rather than adding a
# second one.
const CURRENT_MODULE = "CurrentModule = PathCompleteCertificates\n"

function with_current_module(content)
    marker = "```@meta\n"
    occursin(marker, content) &&
        return replace(content, marker => marker * CURRENT_MODULE; count = 1)
    return marker * CURRENT_MODULE * "```\n\n" * content
end

if !SKIP_LITERATE
    for stem in example_stems()
        file = joinpath(EXAMPLES_DIR, stem * ".jl")
        Literate.markdown(file, OUTPUT_DIR; postprocess = with_current_module)
        Literate.script(file, OUTPUT_DIR)
    end
end

has_page(stem) = !SKIP_LITERATE || isfile(joinpath(OUTPUT_DIR, stem * ".md"))

const EXAMPLE_PAGES = [
    example_title(joinpath(EXAMPLES_DIR, stem * ".jl")) => "generated/$stem.md" for
    stem in example_stems() if has_page(stem)
]

DocMeta.setdocmeta!(
    PathCompleteCertificates,
    :DocTestSetup,
    :(using PathCompleteCertificates);
    recursive = true,
)

const PAGES = Any[
    "Home" => "index.md",
    "Manual" => [
        "Path-complete graphs" => "manual/graphs.md",
        "Templates" => "manual/templates.md",
        "Problems" => "manual/problems.md",
        "What works with what" => "manual/support.md",
    ],
]

isempty(EXAMPLE_PAGES) || push!(PAGES, "Examples" => EXAMPLE_PAGES)

push!(
    PAGES,
    "API Reference" => [
        "Systems and aggregation" => "reference/systems.md",
        "Graphs" => "reference/graphs.md",
        "Templates" => "reference/templates.md",
        "Problems" => "reference/problems.md",
    ],
)
push!(
    PAGES,
    "Developer Docs" => [
        "Set up" => "developers/setup.md",
        "Conventions" => "developers/conventions.md",
        "Adding an example" => "developers/examples.md",
        "Git" => "developers/git.md",
    ],
)
push!(PAGES, "Bibliography" => "bibliography.md")

makedocs(;
    modules = [PathCompleteCertificates],
    sitename = "PathCompleteCertificates.jl",
    authors = "Léa Ninite, Julien Calbert, Raphaël M. Jungers",
    format = Documenter.HTML(;
        canonical = "https://dionysos-dev.github.io/PathCompleteCertificates.jl",
        prettyurls = get(ENV, "CI", "false") == "true",
    ),
    pages = PAGES,
    plugins = [
        DocumenterCitations.CitationBibliography(
            joinpath(SRC_DIR, "references.bib");
            style = :authoryear,
        ),
    ],
    # The tool paper has six pages including references, so it cannot explain
    # the package -- these docs have to. Note that the package exports nothing
    # deliberately, so `checkdocs = :all` has no symbol list to work from and
    # checks nothing; `test/docstrings.jl` is the gate that actually bites.
    checkdocs = :all,
)

deploydocs(;
    repo = "github.com/dionysos-dev/PathCompleteCertificates.jl",
    devbranch = "master",
    # Previews are cleaned up by .github/workflows/doc-preview-cleanup.yml.
    push_preview = true,
)
