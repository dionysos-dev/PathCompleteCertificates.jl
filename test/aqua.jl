module TestAqua

using Test
import PathCompleteCertificates as PCC
using Aqua

@testset "Aqua" begin
    Aqua.test_all(PCC)
end

end
