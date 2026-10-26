```@meta
CurrentModule = PathCompleteCertificates
```

# Template reference

A template is a SetProg family. The constructors below build the families that
[Choosing a template](@ref) presents, and stability also accepts SetProg
families directly; [What works with what](@ref) says which problems each
supports.

## Constructors

```@autodocs
Modules = [PathCompleteCertificates]
Pages = [
    "templates/catalogue/quadratic.jl",
    "templates/catalogue/sum_of_squares.jl",
    "problems/polytope_compat.jl",
]
```

## The template interface

What a template provides to a problem: the primitives that build its node
functions and edge inequalities, and what the package needs to know about it.
[Extending the package](@ref) says which to implement for a new family.

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["templates/abstract.jl", "problems/gauges.jl", "problems/sets.jl"]
```

## SetProg families

The families of [SetProg](https://github.com/blegat/SetProg.jl), which the
constructors return and stability accepts directly. Safety accepts quadratic
and polynomial families.

```@autodocs
Modules = [SetProg]
Pages = ["variables.jl"]
```
