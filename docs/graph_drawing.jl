# Drawings of graphs with two modes, shared by the pages of the manual, which
# include this file in a hidden setup block.

using Plots

const MODE_COLORS = [:royalblue, :darkorange]

# A drawing of a graph with two modes, its nodes at the given positions and
# filled with the given colors.
function draw_graph(
    graph,
    positions;
    title,
    node_colors = fill(:white, length(positions)),
    xlims = (-1.9, 1.9),
    ylims = (-0.75, 0.75),
)
    panel = plot(;
        aspect_ratio = :equal,
        framestyle = :none,
        legend = false,
        title,
        titlefontsize = 10,
        xlims,
        ylims,
    )
    for edge in PCC.edges(graph)
        a, b = PCC.source(edge), PCC.dest(edge)
        mode = only(PCC.letters(PCC.label(graph, edge)))
        color = MODE_COLORS[mode]
        if a == b
            # A loop on the side of the node, away from the other nodes; on a
            # node alone, mode 1 on the left and mode 2 on the right.
            x, y = positions[a]
            side = x == 0 ? (mode == 1 ? -1 : 1) : sign(x)
            t = range(-0.85pi, 0.85pi; length = 50)
            plot!(
                panel,
                x .+ side .* (0.38 .+ 0.32 .* cos.(t)),
                y .+ 0.32 .* sin.(t);
                color,
                lw = 2,
                arrow = arrow(:closed, 0.25, 0.25),
            )
            annotate!(panel, x + side * 0.85, y, text("$mode", 10, color))
        else
            # An arc bent to the left of its direction, so that opposite edges part.
            (x1, y1), (x2, y2) = positions[a], positions[b]
            cx, cy = (x1 + x2) / 2 - 0.25 * (y2 - y1), (y1 + y2) / 2 + 0.25 * (x2 - x1)
            s = range(0.12, 0.88; length = 50)
            xs = (1 .- s) .^ 2 .* x1 .+ 2 .* (1 .- s) .* s .* cx .+ s .^ 2 .* x2
            ys = (1 .- s) .^ 2 .* y1 .+ 2 .* (1 .- s) .* s .* cy .+ s .^ 2 .* y2
            plot!(panel, xs, ys; color, lw = 2, arrow = arrow(:closed, 0.25, 0.25))
            annotate!(panel, cx, cy + 0.12 * sign(x2 - x1), text("$mode", 10, color))
        end
    end
    for (node, (x, y)) in enumerate(positions)
        scatter!(
            panel,
            [x],
            [y];
            markersize = 16,
            color = node_colors[node],
            markerstrokewidth = 2,
        )
        annotate!(panel, x, y, text("$node", 10))
    end
    return panel
end
