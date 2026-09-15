# Shared test harness — included by every test file so they share one set of imports and
# helpers instead of re-declaring them.
#
# Usage (works both under runtests.jl and when a file is run standalone):
#
#     import PathCompleteCertificates
#     include(joinpath(dirname(dirname(pathof(PathCompleteCertificates))), "test", "testsetup.jl"))
#
# The path is resolved from `pathof` so it is independent of the caller's depth. Everything
# below is defined in the *includer's* module scope, keeping each test file a self-contained,
# standalone-runnable module:
#
#     julia --project=test test/graphs/predicates.jl

using Test

const PCC = PathCompleteCertificates
