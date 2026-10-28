module PathCompleteCertificatesSumOfSquaresExt

import PathCompleteCertificates as PCC
import SetProg
import SumOfSquares
import LinearAlgebra

function PCC._unit_set(family::SetProg.PolySet; scale = 1)
    d = div(family.degree, 2)
    monos = SumOfSquares.MP.monomials(family.variables, d)
    coefficients = [
        scale * factorial(d) / prod(factorial, SumOfSquares.MP.exponents(mono)) for
        mono in monos
    ]
    gram = SumOfSquares.GramMatrix(Matrix(LinearAlgebra.Diagonal(coefficients)), monos)
    return SetProg.Sets.PolySet(family.degree, gram)
end

function PCC._gauge(V::Union{SetProg.Sets.PolySet, SetProg.Sets.ConvexPolySet}, x)
    p = SumOfSquares.MP.polynomial(V.p)
    return p(SumOfSquares.MP.variables(p) => x)
end

function PCC._safety_reference(f::SetProg.PolySet, sign)
    x = f.variables
    MP = SumOfSquares.MP
    d = div(PCC._safety_degree(f), 2)
    monos = MP.monomials(x, 0:d)
    # Multinomial weights give sign * w(x), where
    # w(x) = (1 + x₁² + ⋯ + xₙ²)^d. For n = 2 and d = 2,
    # w(x) = 1 + 2x₁² + 2x₂² + x₁⁴ + 2x₁²x₂² + x₂⁴.
    coefficients = [
        sign * factorial(d) /
        (factorial(d - MP.degree(m)) * prod(factorial, MP.exponents(m))) for m in monos
    ]
    coefficients[end] += 1
    gram = SumOfSquares.GramMatrix(Matrix(LinearAlgebra.Diagonal(coefficients)), monos)
    return SetProg.Sets.PolySet(f.degree, gram)
end

end
