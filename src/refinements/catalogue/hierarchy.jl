"""
    Hierarchy(lift)

`lift` applied to the whole graph at every step. From the one-node graph,
[`PathDependentLift`](@ref)`(1)` walks the [`de_bruijn`](@ref) graphs
[philippe2016stability](@cite), and [`CompositionLift`](@ref)`(1)` the
composition lifts of [jongeneel2025ordering; §IV-A](@cite). Throws unless
`lift` [`is_valid`](@ref) for the template on the system.
"""
struct Hierarchy{L <: AbstractLift} <: AbstractRefinementAlgorithm
    lift::L
end

function next_graph(
    algorithm::Hierarchy,
    certificate::AbstractCertificate;
    atol::Real,
    solve,
)
    step = algorithm.lift

    is_valid(step, template(certificate), problem(certificate).system) || throw(
        ArgumentError(
            "$step is not valid for $(template(certificate)) on this system: neither " *
            "the template nor its dual is closed under what the lift requires",
        ),
    )

    return lift(step, graph(certificate)), nothing
end
