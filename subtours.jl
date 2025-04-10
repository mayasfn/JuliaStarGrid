using JuMP, HiGHS
# using JuMP, Cbc

function get_black_nodes(x_sol::Matrix{Int})
    """
    get_black_nodes(x_sol)

    Retourne un ensemble (Set) de tuples (i,j) pour toutes les cellules occupées (où x_sol[i,j] == 1).
    """
    n = size(x_sol, 1)
    nodes = Set{Tuple{Int,Int}}()
    for i in 1:n, j in 1:n
        if x_sol[i,j] == 1
            push!(nodes, (i,j))
        end
    end
    return nodes
end


function get_neighbors(node::Tuple{Int,Int}, x_sol::Matrix{Int}, up_sol::Matrix{Int}, down_sol::Matrix{Int}, left_sol::Matrix{Int}, right_sol::Matrix{Int})
    """
    get_neighbors(node, x_sol, up_sol, down_sol, left_sol, right_sol)

    Pour une cellule node = (i,j), retourne les voisins connectés via les directions actives.
    Un voisin est ajouté seulement s'il existe (dans la grille) et s'il est noir dans x_sol.
    """
    n = size(x_sol, 1)
    (i,j) = node
    neighbors = Set{Tuple{Int,Int}}()
    # Si up est actif et la cellule au-dessus existe et est noire
    if i > 1 && up_sol[i,j] == 1 && x_sol[i-1,j] == 1
        push!(neighbors, (i-1,j))
    end
    # Si down est actif
    if i < n && down_sol[i,j] == 1 && x_sol[i+1,j] == 1
        push!(neighbors, (i+1,j))
    end
    # Si left est actif
    if j > 1 && left_sol[i,j] == 1 && x_sol[i,j-1] == 1
        push!(neighbors, (i,j-1))
    end
    # Si right est actif
    if j < n && right_sol[i,j] == 1 && x_sol[i,j+1] == 1
        push!(neighbors, (i,j+1))
    end
    return neighbors
end

function dfs_component(start::Tuple{Int,Int}, x_sol::Matrix{Int}, up_sol::Matrix{Int}, down_sol::Matrix{Int}, left_sol::Matrix{Int}, right_sol::Matrix{Int})
    """
    dfs_component(start, x_sol, up_sol, down_sol, left_sol, right_sol)

    Effectue un DFS à partir de start (un tuple (i,j)) et retourne l'ensemble des nœuds connexes.
    """
    visited = Set{Tuple{Int,Int}}()
    stack = [start]
    while !isempty(stack)
        node = pop!(stack)
        if !(node in visited)
            push!(visited, node)
            for nb in get_neighbors(node, x_sol, up_sol, down_sol, left_sol, right_sol)
                if !(nb in visited)
                    push!(stack, nb)
                end
            end
        end
    end
    return visited
end


function detect_subtour(x_sol::Matrix{Int}, up_sol::Matrix{Int}, down_sol::Matrix{Int}, left_sol::Matrix{Int}, right_sol::Matrix{Int})
    """
    detect_subtour(x_sol, up_sol, down_sol, left_sol, right_sol)

    Retourne (has_subtour, S)
    - has_subtour est vrai si le composant connexe trouvé (via DFS) ne contient pas toutes les cellules occupées.
    - S est le sous-ensemble (ensemble de tuples) correspondant au composant connexe trouvé.
    Si aucune cellule noire n'existe, S est vide.
    """
    all_nodes = get_black_nodes(x_sol)
    if isempty(all_nodes)
        return (false, Set{Tuple{Int,Int}}())
    end
    # Démarrer le DFS à partir d'un nœud noir choisi arbitrairement
    start = first(all_nodes)
    comp = dfs_component(start, x_sol, up_sol, down_sol, left_sol, right_sol)
    has_subtour = (length(comp) < length(all_nodes))
    return (has_subtour, comp)
end


function add_connectivity_cut!(model::Model, S::Set{Tuple{Int,Int}}, up, down, left, right, n::Int)
    """
    add_connectivity_cut!(model, S, up, down, left, right, n)

    Ajoute au modèle une contrainte pour éliminer le sous-tour isolé correspondant à S.
    On somme les arcs sortants de S (pour chaque cellule de S, on regarde si une direction active mène vers un voisin NON dans S)
    et on impose que cette somme soit au moins 2.
    """
    # Crée une liste d'expressions pour les arcs sortants de S
    expr_terms = @expression(model, 0)
    for (i,j) in S
        # Vérifier le voisin UP
        if i > 1 && !((i-1,j) in S) && j <= n
            expr_terms += up[i,j]
        end
        # Voisin DOWN
        if i < n && !((i+1,j) in S) && j <= n
            expr_terms += down[i,j]
        end
        # Voisin LEFT
        if j > 1 && !((i,j-1) in S)
            expr_terms += left[i,j]
        end
        # Voisin RIGHT
        if j < n && !((i,j+1) in S)
            expr_terms += right[i,j]
        end
    end
    @constraint(model, expr_terms >= 2)
end

function displayGrid(x_sol::Array{Int,2}, up_sol, down_sol, left_sol, right_sol)
    n = size(x_sol, 1)

    # Ligne de séparation complète, avec + à la fin
    function separator_line(n)
        return "+" * join(fill("-----", n), "+") * "+"
    end

    sep = separator_line(n)
    println(sep)

    for i in 1:n
        row_str = "|"
        for j in 1:n
            if x_sol[i, j] == 1
                # Choisir une combinaison de directions (max 2 flèches)
                if up_sol[i,j] == 1 && down_sol[i,j] == 1
                    cell = "↑↓"
                elseif left_sol[i,j] == 1 && right_sol[i,j] == 1
                    cell = "←→"
                elseif up_sol[i,j] == 1 && right_sol[i,j] == 1
                    cell = "↑→"
                elseif up_sol[i,j] == 1 && left_sol[i,j] == 1
                    cell = "←↑"
                elseif down_sol[i,j] == 1 && right_sol[i,j] == 1
                    cell = "↓→"
                elseif down_sol[i,j] == 1 && left_sol[i,j] == 1
                    cell = "←↓"
                elseif up_sol[i,j] == 1
                    cell = " ↑"
                elseif down_sol[i,j] == 1
                    cell = " ↓"
                elseif left_sol[i,j] == 1
                    cell = "← "
                elseif right_sol[i,j] == 1
                    cell = " →"
                else
                    cell = " *"
                end
                row_str *= " " * cell * " |"
            else
                row_str *= "     |"
            end
        end
        println(row_str)
        println(sep)
    end
end

function print_ascii_blocks_with_borders(x::Matrix{Int}, up::Matrix{Int}, down::Matrix{Int}, left::Matrix{Int}, right::Matrix{Int})
    n = size(x, 1)
    border = "─"^((n * 4) + 1)
    println(border)
    for i in 1:n
        for row in 1:3  # 3 lignes par cellule
            line = "|"
            for j in 1:n
                cell = "   "  # Par défaut, cellule vide
                if x[i,j] == 1
                    if row == 1
                        cell = up[i,j] == 1 ? " * " : "   "
                    elseif row == 2
                        left_char  = left[i,j] == 1 ? "*" : " "
                        center     = "*"
                        right_char = right[i,j] == 1 ? "*" : " "
                        cell = left_char * center * right_char
                    else
                        cell = down[i,j] == 1 ? " * " : "   "
                    end
                end
                line *= cell * "|"
            end
            println(line)
        end
        println(border)
    end
end

function gridSolver(lignes::Vector{Int}, colonnes::Vector{Int})
    n = length(lignes)
    totalBlack = sum(lignes)  # Nombre total de cases occupées

    model = Model(HiGHS.Optimizer)

    # Variables x : 1 si la case (i,j) est noire
    @variable(model, x[1:n, 1:n], Bin)
    # Variables directionnelles (chaque cellule noire a exactement 2 directions actives)
    @variable(model, up[1:n, 1:n], Bin)
    @variable(model, down[1:n, 1:n], Bin)
    @variable(model, left[1:n, 1:n], Bin)
    @variable(model, right[1:n, 1:n], Bin)

    # Contraintes sur le nombre de cases occupées par ligne et par colonne
    @constraint(model, [i in 1:n], sum(x[i, j] for j in 1:n) == lignes[i])
    @constraint(model, [j in 1:n], sum(x[i, j] for i in 1:n) == colonnes[j])

    # Chaque case a 1 entrée et 1 sortie (soit 2 directions actives)
    @constraint(model, [i in 1:n, j in 1:n],
        up[i,j] + down[i,j] + left[i,j] + right[i,j] == 2 * x[i,j]
    )

    # Contraintes de cohérence des arcs (les flèches doivent être "réciproques")
    @constraint(model, [i in 2:n, j in 1:n], up[i,j] <= down[i-1,j])
    @constraint(model, [i in 2:n, j in 1:n], down[i-1,j] <= up[i,j])
    @constraint(model, [i in 1:n, j in 1:(n-1)], right[i,j] <= left[i,j+1])
    @constraint(model, [i in 1:n, j in 1:(n-1)], left[i,j+1] <= right[i,j])
    
    # Contraintes sur les bords de la grille
    @constraint(model, [i in 1:n], left[i,1] == 0)
    @constraint(model, [i in 1:n], right[i,n] == 0)
    @constraint(model, [j in 1:n], up[1,j] == 0)
    @constraint(model, [j in 1:n], down[n,j] == 0)

    @objective(model, Min, 0)
    optimize!(model)

    if termination_status(model) != MOI.OPTIMAL
        println("Pas de solution optimale trouvée.")
        return -1
    end

    # Récupère les solutions courantes
    x_sol     = round.(Int, value.(x))
    up_sol    = round.(Int, value.(up))
    down_sol  = round.(Int, value.(down))
    left_sol  = round.(Int, value.(left))
    right_sol = round.(Int, value.(right))

    # Détection itérative des sous-tours via le graphe défini par (x_sol, up_sol, down_sol, left_sol, right_sol)
    # On utilise le DFS sur le graphe des cellules occupées.
    has_subtour, comp = detect_subtour(x_sol, up_sol, down_sol, left_sol, right_sol)
    while has_subtour
        println("Sous-tour détecté sur S = ", comp)
        # Ajouter une coupure pour forcer au moins 2 arcs sortants du composant comp.
        add_connectivity_cut!(model, comp, up, down, left, right, n)
        optimize!(model)
        x_sol     = round.(Int, value.(x))
        up_sol    = round.(Int, value.(up))
        down_sol  = round.(Int, value.(down))
        left_sol  = round.(Int, value.(left))
        right_sol = round.(Int, value.(right))
        has_subtour, comp = detect_subtour(x_sol, up_sol, down_sol, left_sol, right_sol)
    end

    println("")
    print_ascii_blocks_with_borders(x_sol, up_sol, down_sol, left_sol, right_sol)
    # displayGrid(x_sol, up_sol, down_sol, left_sol, right_sol)
    return 0
end

function main()
    print("SOLVE-----------------------")
    # gridSolver([5,3,3,5,2], [5,5,2,2,4])
    # gridSolver([4,5,3,3,3],[3,4,3,3,5])
    # gridSolver([3,5,2,5,3],[3,2,4,5,4])
    # gridSolver([3,4,5,4,2],[4,4,3,3,4]) #SOUS TOUR
    # gridSolver([3,4,3,2,6,2],[4,4,2,3,2,5])
    # gridSolver([4,5,5,2,5,5],[4,5,4,5,5,3])

end

main()
