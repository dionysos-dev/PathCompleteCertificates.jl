module TestAqua

import PathCompleteCertificates
include(
    joinpath(dirname(dirname(pathof(PathCompleteCertificates))), "test", "testsetup.jl"),
)

using Aqua

@testset "Aqua" begin
    Aqua.test_all(PathCompleteCertificates)
end

end
