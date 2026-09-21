# # Simulating: what a run looks like
#
# A certificate quantifies over *every* switching sequence. A simulation takes
# *one*. This example is about the second.

import PathCompleteCertificates as PCC
using Random
using Plots

# Two modes on the plane: a contraction and a rotation. Neither is the whole
# story under switching.

A = [[0.5 0.0; 0.0 0.25], [0.0 1.0; -1.0 0.0]]
system = PCC.switched_system(A)

# ## A given switching sequence
#
# Pass the word and you get exactly that run. This is the form to use in a test
# — Julia's default random stream is not stable across releases, so a test that
# pins an exact trajectory must not depend on it.

PCC.simulate(system, [1.0, 1.0], [1, 2, 1, 2])

# The accessors: one more state than step, and the mode that carried each state
# to the next.

trajectory = PCC.simulate(system, [1.0, 1.0], [1, 2, 1, 2])
PCC.switching(trajectory), length(PCC.states(trajectory))

# ## Random switching respects the automaton
#
# With an integer instead of a word, the mode at each step is drawn from the
# modes the system's switching automaton **admits** — not from `1:n`. That
# distinction is invisible on the system above, where every mode is always
# available, and load-bearing on a constrained one.

using HybridSystems

constraint = GraphAutomaton(2)             # mode 2 may not follow mode 2
add_transition!(constraint, 1, 1, 1)
add_transition!(constraint, 1, 2, 2)
add_transition!(constraint, 2, 1, 1)

constrained = PCC.switched_system(A; automaton = constraint)

rng = MersenneTwister(42)
word = PCC.switching(PCC.simulate(constrained, [1.0, 1.0], 20; rng = rng))

# No two consecutive `2`s, by construction:

any(word[k] == 2 && word[k + 1] == 2 for k in 1:(length(word) - 1))

# Asking for an inadmissible sequence is an error rather than a silent
# adjustment:

try
    PCC.simulate(constrained, [1.0, 1.0], [2, 2])
catch err
    err
end

# ## Plotting
#
# The package carries a plotting recipe as a package extension, so `plot` works
# on a trajectory as soon as Plots is loaded — and Plots is never a dependency
# of the package itself.

rng = MersenneTwister(7)
run = PCC.simulate(system, [1.0, 1.0], 25; rng = rng)

plot(run; title = "one run of a switched system", lw = 2)

# The default view is each coordinate against the step, which works for any
# state dimension. A phase portrait is two lines away when the state is planar:

visited = PCC.states(run)

plot(
    getindex.(visited, 1),
    getindex.(visited, 2);
    aspect_ratio = :equal,
    framestyle = :origin,
    marker = :circle,
    markersize = 2,
    lw = 1,
    label = "trajectory",
    title = "the same run, in the plane",
)
