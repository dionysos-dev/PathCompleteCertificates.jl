# The methods of `SumOfSquaresTemplate`.
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

    # Turns the plain JuMP model into a `SOSModel`.
    SumOfSquares.PolyJuMP.setpolymodule!(model, SumOfSquares)

    return JuMP.@variable(
        model,
        variable_type = SOSPoly(monomials(template.variables, template.degree))
    )
end

# V(x) >= min_scale * ||x||^(2 degree).
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

    # For a numeric scale = gamma^(2d), impose V_src(x) - V_dst((A/gamma) x) >= 0,
    # which is better conditioned; a JuMP expression has no root to take.
    residual = if scale isa Real
        gamma = scale^(1 / PCC.homogeneity_degree(template))
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
