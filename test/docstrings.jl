module TestDocstrings

# The package exports nothing deliberately, so `checkdocs = :all` has no symbol
# list to work from and checks nothing. That is how eight `raw"""` docstrings --
# which never attach, being non-standard string literals -- and nine graph
# queries went undocumented without the build noticing.
#
# This is the replacement: every name a user can reach as `PCC.name` carries a
# docstring. Underscore-prefixed names are internal by the convention in
# CLAUDE.md §4 and are exempt.

using Test
import PathCompleteCertificates as PCC

reachable = filter(names(PCC; all = true, imported = false)) do name
    text = string(name)

    startswith(text, "#") && return false          # gensyms
    startswith(text, "_") && return false          # internal by convention
    text in ("PathCompleteCertificates", "eval", "include") && return false

    return true
end

documented = Set(
    replace(string(binding), "PathCompleteCertificates." => "") for
    binding in keys(Base.Docs.meta(PCC))
)

@testset "every reachable name is documented" begin
    @test !isempty(reachable)

    undocumented = sort([string(n) for n in reachable if !(string(n) in documented)])

    if !isempty(undocumented)
        @info "names reachable as PCC.name with no docstring" undocumented
    end

    @test isempty(undocumented)
end

@testset "docstrings actually attach" begin
    # `raw"""..."""` is a macro call, not a string literal, so Julia does not
    # treat it as a docstring and the binding silently ends up undocumented.
    # The check above catches the consequence; this one names the cause, so a
    # failure says what to do about it.
    sources = String[]

    for (root, _, files) in walkdir(joinpath(@__DIR__, "..", "src"))
        for file in files
            endswith(file, ".jl") || continue
            occursin("raw\"\"\"", read(joinpath(root, file), String)) &&
                push!(sources, file)
        end
    end

    @test isempty(sources)
end

end
