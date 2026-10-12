# Plot recipe for `Trajectory`.
module PathCompleteCertificatesRecipesBaseExt

import RecipesBase
import PathCompleteCertificates as PCC

# Each coordinate against the step index, which works in every dimension.
RecipesBase.@recipe function _(trajectory::PCC.Trajectory)
    visited = PCC.states(trajectory)
    dimension = length(first(visited))

    xguide --> "step"
    yguide --> "state"
    label --> reshape(["x[$i]" for i in 1:dimension], 1, dimension)

    return 0:length(trajectory), [x[i] for x in visited, i in 1:dimension]
end

end
