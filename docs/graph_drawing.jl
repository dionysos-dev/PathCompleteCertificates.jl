# Drawings of graphs with two modes, shared by the pages of the manual and the
# tutorials, which include this file in a hidden setup block.

using Plots

const MODE_COLORS = [:royalblue, :darkorange]

# `n` positions evenly spaced on a circle, the first at the top.
circle_positions(n; radius = 2.0) =
    [(radius * sin(2pi * (k - 1) / n), radius * cos(2pi * (k - 1) / n)) for k in 1:n]

# A drawing of a graph with two modes, its nodes at the given positions and
# filled with the given colors and labelled with the given labels. With
# `emphasized`, a collection of edges, the other edges are faded and unlabelled;
# with `mode_labels = false`, no edge is labelled, the colors telling the modes.
function draw_graph(
    graph,
    positions;
    title,
    node_colors = fill(:white, length(positions)),
    node_labels = string.(eachindex(positions)),
    mode_labels = true,
    emphasized = nothing,
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
        bold = emphasized === nothing || edge in emphasized
        style = (; color, lw = bold ? 2 : 1, alpha = bold ? 1.0 : 0.25)
        if a == b
            # A loop pointing away from the centre; on a node at the centre,
            # mode 1 on the left and mode 2 on the right.
            x, y = positions[a]
            u = hypot(x, y) > 0 ? (x, y) ./ hypot(x, y) : (mode == 1 ? -1.0 : 1.0, 0.0)
            v = u[2] > 0 || (u[2] == 0 && u[1] > 0) ? (-u[2], u[1]) : (u[2], -u[1])
            t = range(-0.85pi, 0.85pi; length = 50)
            plot!(
                panel,
                x .+ u[1] .* (0.38 .+ 0.32 .* cos.(t)) .+ v[1] .* 0.32 .* sin.(t),
                y .+ u[2] .* (0.38 .+ 0.32 .* cos.(t)) .+ v[2] .* 0.32 .* sin.(t);
                style...,
                arrow = arrow(:closed, 0.25, 0.25),
            )
            bold &&
                mode_labels &&
                annotate!(panel, x + 0.85 * u[1], y + 0.85 * u[2], text("$mode", 10, color))
        else
            # An arc bent to the left of its direction, so that opposite edges part.
            (x1, y1), (x2, y2) = positions[a], positions[b]
            cx, cy = (x1 + x2) / 2 - 0.25 * (y2 - y1), (y1 + y2) / 2 + 0.25 * (x2 - x1)
            s = range(0.12, 0.88; length = 50)
            xs = (1 .- s) .^ 2 .* x1 .+ 2 .* (1 .- s) .* s .* cx .+ s .^ 2 .* x2
            ys = (1 .- s) .^ 2 .* y1 .+ 2 .* (1 .- s) .* s .* cy .+ s .^ 2 .* y2
            plot!(panel, xs, ys; style..., arrow = arrow(:closed, 0.25, 0.25))
            bold &&
                mode_labels &&
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
        annotate!(panel, x, y, text(node_labels[node], 10))
    end
    return panel
end

# A grid of drawings, one per graph, each on a circle, its nodes labelled by
# `node_label` and its edges by their colors alone.
function draw_graphs(graphs, titles; node_label = string, columns = 3)
    panels = map(graphs, titles) do graph, title
        n = PCC.n_nodes(graph)
        positions = n == 1 ? [(0.0, 0.0)] : circle_positions(n; radius = 2.0)
        return draw_graph(
            graph,
            positions;
            title,
            node_labels = node_label.(1:n),
            mode_labels = false,
            xlims = (-3.2, 3.2),
            ylims = (-3.2, 3.2),
        )
    end
    rows = cld(length(panels), columns)
    blanks = [plot(; framestyle = :none) for _ in 1:(rows * columns - length(panels))]
    return plot(
        panels...,
        blanks...;
        layout = (rows, columns),
        size = (300columns, 300rows),
    )
end

# The graph of a certificate on a circle, its tight edges in bold.
function draw_tight_edges(certificate; title = "the last graph, tight edges in bold")
    graph = PCC.graph(certificate)
    return draw_graph(
        graph,
        circle_positions(PCC.n_nodes(graph); radius = 2.4);
        title,
        emphasized = PCC.tight_edges(certificate),
        xlims = (-3.6, 3.6),
        ylims = (-3.6, 3.6),
    )
end
