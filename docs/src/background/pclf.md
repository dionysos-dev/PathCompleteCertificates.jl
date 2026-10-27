```@meta
CurrentModule = PathCompleteCertificates
```

# Path-complete Lyapunov functions

## The joint spectral radius

A switched linear system ``x_{k+1} = A_{\sigma(k)} x_k``, with modes
``1, \dots, M``, has joint spectral radius

```math
\rho = \lim_{k \to \infty} \max_{w \in \{1, \dots, M\}^k} \lVert A_w \rVert^{1/k},
\qquad A_w = A_{w_k} \cdots A_{w_1}.
```

It is stable under arbitrary switching exactly when ``\rho < 1``.

## Path-complete graphs

A graph on the modes has edges ``(a, b, w)`` reading a word ``w``, a sequence
of modes. Its expanded graph replaces each edge reading a word of length ``k``
by a path of ``k`` edges reading one mode each
([ahmadi2014joint](@cite), Def. 2.1). The graph is **path-complete** when every
finite word is read along a path of its expanded graph (Def. 2.2).

## The stability theorem

Let ``G`` be path-complete, and let positive, continuous functions ``V_a``,
homogeneous of degree ``p``, one per node, satisfy on every edge
``(a, b, w)``

```math
V_b(A_w x) \le \gamma^{p\,|w|} \, V_a(x) \quad \text{for every } x.
```

Then ``\rho \le \gamma`` ([ahmadi2014joint](@cite), Thm. 2.4). This is the
inequality that [`StabilityProblem`](@ref) imposes, and [`certify`](@ref)
searches for the smallest ``\gamma``.

## The common function

The node functions of a certificate combine into a single function of the
state, which certifies the same property. On a **complete** graph, where every
node has an outgoing edge for every mode, it is the minimum of the node
functions; on a **co-complete** graph, where every node has an incoming edge
for every mode, the maximum; on any other path-complete graph, a minimum of
maxima over sets of nodes ([philippe2019path](@cite)). [`common`](@ref)
evaluates it.

## Safety and optimal control

The same construction certifies safety with path-complete barrier functions
([anand2024barrier](@cite)): one function per node, negative on the initial
set, positive on the unsafe set and non-increasing along every edge.

For optimal control ([ninite2026path](@cite)), the node functions bound the cost
of a state feedback with one gain per node. The edge inequality is convex in
the unknowns only after the substitution ``S = P^{-1}``, ``Y = K S``, which ties
the problem to the quadratic template.
