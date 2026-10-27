```@meta
CurrentModule = PathCompleteCertificates
```

# Why duality holds

The dual graph reverses every edge, and the order of every word
([debauche2024thesis](@cite), Def. 6.3). It is path-complete exactly when the
graph is (Prop. 6.6).

For a template of norms, node functions form a certificate on a graph for a
system exactly when their dual norms form a certificate on the dual graph for
the transposed system (Lemma 6.25). This is the certificate that
[`dual`](@ref) returns. Applying the construction twice gives back the
original graph, system and functions.

Two consequences:

- **The order between graphs.** ``G \le_{\mathcal V} H`` exactly when
  ``\mathrm{dual}(G) \le_{\mathcal V^*} \mathrm{dual}(H)``, where
  ``\mathcal V^*`` is the template of the dual norms (Prop. 6.27).
- **The validity of lifts.** A lift is valid for a template exactly when its
  dual lift is valid for the dual template (Prop. 7.5). The min and max lifts
  are each other's duals (Lemma 7.45). This is how [`is_valid`](@ref) reads the
  validity of the min lift for the linear copositive template: through the
  dual copositive template, which is closed under maximum.
