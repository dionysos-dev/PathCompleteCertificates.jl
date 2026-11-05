# Drawings of graphs with two modes, shared by the pages of the manual and the
# tutorials, which include this file in a hidden setup block.

using Plots

const MODE_COLORS = [:royalblue, :darkorange]

# `n` positions evenly spaced on a circle, the first at the top.
circle_positions(n; radius = 2.0) =
    [(radius * sin(2pi * (k - 1) / n), radius * cos(2pi * (k - 1) / n)) for k in 1:n]

_unit(v) = v ./ hypot(v...)
_rotate(v, angle) =
    (cos(angle) * v[1] - sin(angle) * v[2], sin(angle) * v[1] + cos(angle) * v[2])

# The points of a curve outside the disks of radius `r` around `a` and `b`, so
# that an edge starts and ends on the boundary of its nodes.
_outside(points, a, b, r) =
    filter(p -> hypot((p .- a)...) > r && hypot((p .- b)...) > r, points)

# A drawing of a graph with two modes, its nodes at the given positions and
# filled with the given colors and labelled with the given labels. With
# `emphasized`, a collection of edges, the other edges are faded and unlabelled;
# with `mode_labels = false`, no edge is labelled, the colors telling the modes.
# `node_radius` is in the units of the positions.
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
    node_radius = 0.22,
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
    r = node_radius
    center = (sum(first, positions), sum(last, positions)) ./ length(positions)
    edge_list = collect(PathCompleteCertificates.edges(graph))
    source(e) = PathCompleteCertificates.source(e)
    dest(e) = PathCompleteCertificates.dest(e)
    mode(e) =
        only(PathCompleteCertificates.letters(PathCompleteCertificates.label(graph, e)))

    # The edges between the same two nodes, or the loops at the same node, in a
    # fixed order, so that each gets its own bend or direction.
    group(e) = minmax(source(e), dest(e))
    rank(e) = (source(e) > dest(e), mode(e))
    siblings(e) = sort(filter(f -> group(f) == group(e), edge_list); by = rank)

    for edge in edge_list
        a, b, i = source(edge), dest(edge), mode(edge)
        color = MODE_COLORS[i]
        bold = emphasized === nothing || edge in emphasized
        style = (; color, lw = bold ? 2 : 1, alpha = bold ? 1.0 : 0.25)
        group_edges = siblings(edge)
        k, m = findfirst(==(edge), group_edges), length(group_edges)
        p = positions[a]
        if a == b
            # A loop outside the node, pointing away from the centre of the
            # drawing, the loops of one node spread around that direction: on a
            # node at the centre, mode 1 on the left and mode 2 on the right.
            away = hypot((p .- center)...) > 1e-9 ? _unit(p .- center) : (0.0, 1.0)
            spread = hypot((p .- center)...) > 1e-9 ? 0.7 : pi / 2
            u = _rotate(away, -(k - (m + 1) / 2) * 2 * spread / max(m - 1, 1))
            loop_radius = r
            c = p .+ (r + 0.65loop_radius) .* u
            start = atan(-u[2], -u[1])
            t = range(start, start + 2pi; length = 120)
            points = [c .+ loop_radius .* (cos(s), sin(s)) for s in t]
            points = filter(q -> hypot((q .- p)...) > r, points)
            plot!(
                panel,
                first.(points),
                last.(points);
                style...,
                arrow = arrow(:closed, 0.2, 0.2),
            )
            label_at = c .+ (loop_radius + 0.16) .* u
        else
            # An arc, straight when it is alone between its nodes, and bent
            # apart from the other edges between the same two nodes otherwise.
            q = positions[b]
            low, high = positions[min(a, b)], positions[max(a, b)]
            normal = _rotate(_unit(high .- low), pi / 2)
            distance = hypot((q .- p)...)
            offset = (k - (m + 1) / 2) * 0.5 * distance
            control = (p .+ q) ./ 2 .+ offset .* normal
            s = range(0, 1; length = 120)
            points = [(1 - t)^2 .* p .+ 2(1 - t) * t .* control .+ t^2 .* q for t in s]
            points = _outside(points, p, q, r + 0.03)
            plot!(
                panel,
                first.(points),
                last.(points);
                style...,
                arrow = arrow(:closed, 0.2, 0.2),
            )
            middle = (p .+ 2 .* control .+ q) ./ 4
            side = offset == 0 ? 1 : sign(offset)
            label_at = middle .+ 0.16 * side .* normal
        end
        bold && mode_labels && annotate!(panel, label_at..., text("$i", 9, color))
    end

    angles = range(0, 2pi; length = 60)
    for (node, (x, y)) in enumerate(positions)
        plot!(
            panel,
            Shape(x .+ r .* cos.(angles), y .+ r .* sin.(angles));
            fillcolor = node_colors[node],
            linecolor = :black,
            linewidth = 1.5,
        )
        annotate!(panel, x, y, text(node_labels[node], 10))
    end
    return panel
end

# A grid of drawings, one per graph, each on a circle, its nodes labelled by
# `node_label` and its edges by their colors alone.
function draw_graphs(graphs, titles; node_label = string, columns = 3)
    panels = map(graphs, titles) do graph, title
        n = n_nodes(graph)
        positions = n == 1 ? [(0.0, 0.0)] : circle_positions(n; radius = 2.0)
        return draw_graph(
            graph,
            positions;
            title,
            node_labels = node_label.(1:n),
            mode_labels = false,
            xlims = (-3.2, 3.2),
            ylims = (-3.2, 3.2),
            node_radius = 0.38,
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
    graph = get_graph(certificate)
    return draw_graph(
        graph,
        circle_positions(n_nodes(graph); radius = 2.4);
        title,
        emphasized = tight_edges(certificate),
        xlims = (-3.6, 3.6),
        ylims = (-3.6, 3.6),
        node_radius = 0.38,
    )
end
