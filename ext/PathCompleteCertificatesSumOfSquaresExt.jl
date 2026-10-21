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

end
