# The sum-of-squares template, as a package extension.
#
# SumOfSquares pulls a large polynomial stack -- MultivariatePolynomials,
# MultivariateMoments, SemialgebraicSets and the rest -- and two of the three
# synthesis paths in this package are linear programs. Loading that stack in
# order to solve an LP is the cost the conventions refuse, so it stays weak.
#
# SwitchOnSafety.jl reaches sum-of-squares through SetProg, which is the right
# abstraction for the invariant sets it computes and the wrong one here: we need
# one SOS polynomial per node and one SOS constraint per edge, which is
# SumOfSquares directly.
module PathCompleteCertificatesSumOfSquaresExt

import JuMP
import SumOfSquares
import MultivariatePolynomials
import PathCompleteCertificates as PCC

using SumOfSquares: SOSPoly, SOSCone
using MultivariatePolynomials: monomials, subs

function PCC.add_function_variables!(
    model::JuMP.Model,
    template::PCC.SumOfSquaresTemplate,
    dimension::Integer,
    node,
)
    dimension == length(template.variables) || throw(
        ArgumentError(
            "the template carries $(length(template.variables)) polynomial " *
            "variables but the system has dimension $dimension",
        ),
    )

    # `SOSModel` is exactly `Model` plus this call, so the template can adapt an
    # ordinary JuMP model rather than the problem having to build a special one.
    SumOfSquares.PolyJuMP.setpolymodule!(model, SumOfSquares)

    return JuMP.@variable(
        model,
        variable_type = SOSPoly(monomials(template.variables, template.degree))
    )
end

# Excludes V = 0 by asking for V(x) >= min_scale * ||x||^(2 degree), which is
# homogeneous of the same degree as V and so costs no extra conditioning.
function PCC.add_normalization!(
    model::JuMP.Model,
    template::PCC.SumOfSquaresTemplate,
    V;
    min_scale::Real = 1e-3,
)
    x = template.variables

    JuMP.@constraint(model, V - min_scale * sum(x .^ 2)^template.degree in SOSCone())

    return nothing
end

function PCC.add_domination!(
    model::JuMP.Model,
    template::PCC.SumOfSquaresTemplate,
    V_src,
    V_dst,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    x = template.variables

    # Divide the map rather than scale the inequality. V is homogeneous of
    # degree 2d and scale is gamma^(2d), so
    #     scale * V_src(x) - V_dst(A x)  =  gamma^(2d) * (V_src(x) - V_dst((A/gamma) x))
    # and the two constraints are equivalent. The second is far better
    # conditioned when gamma is not near 1 -- the lesson SwitchOnSafety records
    # in `sos.jl`, where it is pushed onto the caller as a scaled system.
    #
    # `scale` is allowed to be a JuMP expression, and a fractional root of one
    # is not expressible. Then there is nothing to fold into the map and the
    # inequality is imposed as written, conditioning and all.
    residual = if scale isa Real
        gamma = scale^(1 / PCC.rate_exponent(template))
        V_src - subs(V_dst, x => (map ./ gamma) * x)
    else
        scale * V_src - subs(V_dst, x => map * x)
    end

    margin == 0 || (residual -= margin * sum(x .^ 2)^template.degree)

    JuMP.@constraint(model, residual in SOSCone())

    return nothing
end

PCC.solution_value(template::PCC.SumOfSquaresTemplate, V) =
    PCC.SumOfSquaresFunction(JuMP.value(V), template.variables)

end
