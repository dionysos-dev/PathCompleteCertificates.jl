# Plotting for `Trajectory`, as a package extension.
#
# RecipesBase is tiny and has no dependencies of its own, so depending on it
# directly would be defensible. It stays a weak dependency because the rule is
# written down twice already -- plotting is never a dependency of the package,
# nor of the environment CI instantiates. Anyone with Plots has RecipesBase
# loaded, so `plot(trajectory)` works for them without the package ever asking
# for it.
module PathCompleteCertificatesRecipesBaseExt

import RecipesBase
import PathCompleteCertificates as PCC

# Each coordinate against the step index, which is the one view that works for
# every state dimension. A phase portrait would only work for n = 2, so it is
# left to the caller rather than guessed at here.
RecipesBase.@recipe function _(trajectory::PCC.Trajectory)
    visited = PCC.states(trajectory)
    dimension = length(first(visited))

    xguide --> "step"
    yguide --> "state"
    label --> reshape(["x[$i]" for i in 1:dimension], 1, dimension)

    return 0:length(trajectory), [x[i] for x in visited, i in 1:dimension]
end

end
