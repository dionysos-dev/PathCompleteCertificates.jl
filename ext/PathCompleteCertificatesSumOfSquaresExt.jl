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
    node::Integer,
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
function PCC.add_normalization!(model::JuMP.Model, template::PCC.SumOfSquaresTemplate, V)
    x = template.variables
    bound = template.min_scale * sum(x .^ 2)^template.degree

    JuMP.@constraint(model, V - bound in SOSCone())

    return nothing
end

function PCC.add_decrease!(
    model::JuMP.Model,
    template::PCC.SumOfSquaresTemplate,
    V_src,
    V_dst,
    map::AbstractMatrix;
    scale::Real = 1,
)
    x = template.variables

    # With scale = gamma^(2d), V_src(x) - V_dst((A/gamma) x) >= 0 is better
    # conditioned than scale * V_src(x) - V_dst(A x) >= 0.
    gamma = scale^(1 / PCC.homogeneity_degree(template))
    JuMP.@constraint(model, V_src - subs(V_dst, x => (map ./ gamma) * x) in SOSCone())

    return nothing
end

PCC.solution_value(template::PCC.SumOfSquaresTemplate, V) =
    PCC.SumOfSquaresFunction(JuMP.value(V), template.variables)

end
