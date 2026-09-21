```@meta
CurrentModule = PathCompleteCertificates
```

# Templates

A template is the **family** the node functions are drawn from.
[`solution_value`](@ref) turns a solved template into the fitted, callable
member.

!!! warning "A template is an instance, never a type"
    Pass `QuadraticTemplate()`, not `QuadraticTemplate`. Some templates carry
    data — [`PolyhedralTemplate`](@ref) holds one matrix per node — and a type
    has nowhere to put it.

## The four templates

| Template | ``V_s(x)`` | Degree | Solved for | Source |
| :-- | :-- | :-: | :-- | :-- |
| [`QuadraticTemplate`](@ref) | ``x^\top P_s x`` | 2 | ``P_s \succ 0`` | standard |
| [`LinearCopositiveTemplate`](@ref) | ``c_s^\top x`` | 1 | ``c_s > 0`` | standard |
| [`PolyhedralTemplate`](@ref) | ``\max_k \lvert (G_s x)_k \rvert / w_{s,k}`` | 1 | weights ``w_s`` | [athanasopoulos2019polyhedral](@cite) |
| [`ConicPolyhedralTemplate`](@ref) | ``\max_i \lvert p_{s,i}^\top x \rvert`` | 1 | facets ``p_{s,i}`` | unpublished ¹ |

¹ The free-facet construction is not yet published — currently under submission.

The degree is [`rate_exponent`](@ref): ``V(cx) = c^d V(x)``. It is accounted for
when rates are computed, so bounds from different templates are comparable.

**The two polyhedral templates** differ in what is fixed.
[`PolyhedralTemplate`](@ref) fixes the facet directions and solves only for the
weights, keeping the program linear. [`ConicPolyhedralTemplate`](@ref) solves for
the facets too: larger, and much less conservative. On a rotation scaled by
`0.9` the fixed-facet template certifies nothing while the conic one reaches
`0.901`.

!!! note "Not every template suits every system"
    [`LinearCopositiveTemplate`](@ref) needs entrywise nonnegative mode
    matrices — ``c^\top x`` certifies nothing about a system that leaves the
    nonnegative orthant. [`check_dynamics`](@ref) throws rather than returning a
    meaningless bound.

See [What works with what](@ref) for which problems accept which template.

## Writing your own

One file, answering a handful of primitives. No change to any problem, so it
works with every problem that accepts it. The interfaces are in the
[developer conventions](@ref "Coding conventions").
