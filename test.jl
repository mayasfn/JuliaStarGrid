# using JuMP, HiGHS
using JuMP, Cbc

function gridSolver(lignes::Vector{Int}, colonnes::Vector{Int})
    n = length(lignes)

    #model = Model(HiGHS.Optimizer)
    model = Model(Cbc.Optimizer)

    @variable(model, x[1:n, 1:n], Bin)  # 1 si la case (i,j) est noire

    # Variables directionnelles (si besoin de développer la modélisation)
    @variable(model, up[1:n, 1:n], Bin)
    @variable(model, down[1:n, 1:n], Bin)
    @variable(model, left[1:n, 1:n], Bin)
    @variable(model, right[1:n, 1:n], Bin)

    # 1) Contraintes sur le nombre de cases noires par ligne et colonne
    @constraint(model, [i in 1:n], sum(x[i, j] for j in 1:n) == lignes[i])
    @constraint(model, [j in 1:n], sum(x[i, j] for i in 1:n) == colonnes[j])

    # 2) Lien entre x et les variables de direction :
    # Si x[i,j] == 0, alors aucune direction ne peut être sélectionnée.
    @constraint(model, [i in 1:n, j in 1:n],
        up[i, j] + down[i, j] + left[i, j] + right[i, j] == 2 * x[i, j]
    )

    # 3) Exemples de contraintes de cohérence entre directions opposées
    @constraint(model, [i in 2:n, j in 1:n], up[i, j] <= down[i-1, j])
    @constraint(model, [i in 2:n, j in 1:n], down[i-1, j] <= up[i, j])
    @constraint(model, [i in 1:n, j in 1:(n-1)], right[i, j] <= left[i, j+1])
    @constraint(model, [i in 1:n, j in 1:(n-1)], left[i, j+1] <= right[i, j])

    # No LEFT on the first column
    @constraint(model, [i in 1:n], left[i, 1] == 0)

    # No RIGHT on the last column
    @constraint(model, [i in 1:n], right[i, n] == 0)

    # No UP on the first row
    @constraint(model, [j in 1:n], up[1, j] == 0)

    # No DOWN on the last row
    @constraint(model, [j in 1:n], down[n, j] == 0)

    # 4) Imposer une direction à chaque case
    @constraint(model, [i in 1:n, j in 1:n], up[i, j] + down[i, j] + left[i, j] + right[i, j] >= x[i, j])

    # La modélisation complète ajouterait ici d'autres contraintes 
    # (par exemple pour imposer un unique chemin connecté, etc.).

    @objective(model, Min, 0)  # Pas de critère d'optimisation particulier

    optimize!(model)

    if termination_status(model) != MOI.OPTIMAL
        println("Pas de solution optimale trouvée.")
        return -1
    end

    x_sol = round.(Int, value.(x))
    up_sol = round.(Int, value.(up))
    down_sol = round.(Int, value.(down))
    left_sol = round.(Int, value.(left))
    right_sol = round.(Int, value.(right))
    # print(up_sol,down_sol,left_sol,right_sol)
    # displayGrid(x_sol, up_sol, down_sol, left_sol, right_sol)
    println("")

    y = build_ascii_matrix(x_sol, up_sol, down_sol, left_sol, right_sol, n)
    composantes = composantes_connexes(y)
    while length(composantes) > 1
        println("Sous-tours détectés : ", length(composantes))
    
        for comp in composantes
            # Convertir (i,j) dans y en (i,j) dans x si possible
            ids_in_x = Set{Tuple{Int,Int}}()
    
            for (yi, yj) in comp
                # Les centres des blocs sont à la position (3*i-1, 3*j-1)
                if yi % 3 == 2 && yj % 3 == 2
                    xi = div(yi - 1, 3) + 1
                    xj = div(yj - 1, 3) + 1
                    push!(ids_in_x, (xi,xj))
                end
            end
    
            if !isempty(ids_in_x)
                @constraint(model, sum(x[i,j] for (i,j) in ids_in_x) <= length(ids_in_x) - 1)
            end
        end

        optimize!(model)

if termination_status(model) != MOI.OPTIMAL
    println("Pas de solution faisable après ajout de contrainte.")
    return -1
end
        x_sol = round.(Int, value.(x))
        up_sol = round.(Int, value.(up))
        down_sol = round.(Int, value.(down))
        left_sol = round.(Int, value.(left))
        right_sol = round.(Int, value.(right))

        y = build_ascii_matrix(x_sol, up_sol, down_sol, left_sol, right_sol, n)
        composantes = composantes_connexes(y)
    end  # ← le `end` manquant ici pour fermer la boucle `while`

    return 0  # ← placé après la fin de la boucle
end  # ← ferme la fonction `gridSolver`

"""
    displayGrid(x_sol)

Affiche la grille solution sous forme de tableau encadré, similaire à l'affichage demandé dans l'exercice.
Une case noire est représentée par " * " et une case vide par des espaces.
"""
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
                if up_sol[i, j] == 1 && down_sol[i, j] == 1
                    cell = "↑↓"
                elseif left_sol[i, j] == 1 && right_sol[i, j] == 1
                    cell = "←→"
                elseif up_sol[i, j] == 1 && right_sol[i, j] == 1
                    cell = "↑→"
                elseif up_sol[i, j] == 1 && left_sol[i, j] == 1
                    cell = "←↑"
                elseif down_sol[i, j] == 1 && right_sol[i, j] == 1
                    cell = "↓→"
                elseif down_sol[i, j] == 1 && left_sol[i, j] == 1
                    cell = "←↓"
                elseif up_sol[i, j] == 1
                    cell = " ↑"
                elseif down_sol[i, j] == 1
                    cell = " ↓"
                elseif left_sol[i, j] == 1
                    cell = "← "
                elseif right_sol[i, j] == 1
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


function print_ascii_blocks_with_borders(x, up, down, left, right)
    n = size(x, 1)
    println("─"^((n * 4) + 1))  # 4 per cell + 1 for start

    for i in 1:n
        for row in 1:3  # 3 rows per cell
            line = "|"
            for j in 1:n
                if x[i, j] == 0
                    cell = "   "  # empty cell
                else
                    if row == 1
                        cell = up[i, j] == 1 ? " * " : "   "
                    elseif row == 2
                        left_char = left[i, j] == 1 ? "*" : " "
                        center = "*"
                        right_char = right[i, j] == 1 ? "*" : " "
                        cell = left_char * center * right_char
                    else
                        cell = down[i, j] == 1 ? " * " : "   "
                    end
                end
                line *= cell * "|"
            end
            println(line)
        end
        # Optional horizontal separator
        println("─"^((n * 4) + 1))  # 4 per cell + 1 for start
    end
end

function build_ascii_matrix(x, up, down, left, right, n)
    y = zeros(Int, 3n, 3n)

    for i in 1:n
        for j in 1:n
            if x[i, j] != 0
                row_base = (i - 1) * 3
                col_base = (j - 1) * 3

                # Top: up[i,j]
                if up[i, j] == 1
                    y[row_base+1, col_base+2] = 1  # center of top row
                end

                # Middle row: left, center, right
                if left[i, j] == 1
                    y[row_base+2, col_base+1] = 1
                end
                y[row_base+2, col_base+2] = 1  # center always
                if right[i, j] == 1
                    y[row_base+2, col_base+3] = 1
                end

                # Bottom: down[i,j]
                if down[i, j] == 1
                    y[row_base+3, col_base+2] = 1
                end
            end
        end
    end

    return y
end

function composantes_connexes(y)
    n = size(y, 1)
    visited = falses(n, n)
    composantes = []

    for i in 1:n, j in 1:n
        if y[i,j] == 1 && !visited[i,j]
            pile = [(i,j)]
            composante = []

            while !isempty(pile)
                (ci,cj) = pop!(pile)
                if !visited[ci,cj]
                    visited[ci,cj] = true
                    push!(composante, (ci,cj))
                    for (di,dj) in [(-1,0),(1,0),(0,-1),(0,1)]  # haut, bas, gauche, droite
                        ni, nj = ci + di, cj + dj
                        if 1 ≤ ni ≤ n && 1 ≤ nj ≤ n && y[ni,nj] == 1 && !visited[ni,nj]
                            push!(pile, (ni,nj))
                        end
                    end
                end
            end
            push!(composantes, composante)
        end
    end

    return composantes
end


function testModels()
    testCases = [
        # Exemple 1 (5x5) : Total = 18
        (lignes=[5, 3, 3, 5, 2], colonnes=[5, 5, 2, 2, 4]),
        # Exemple 2 (4x4) : Total = 8
        (lignes=[2, 1, 3, 2], colonnes=[3, 2, 2, 1]),
        # Exemple 3 (6x6) : Total = 19
        (lignes=[3, 4, 2, 4, 3, 3], colonnes=[4, 3, 3, 3, 3, 3]),
        # Exemple 4 (1x1) : Cas trivial
        (lignes=[1], colonnes=[1]),
        # Exemple 5 (2x2) : Total = 2
        (lignes=[1, 1], colonnes=[1, 1])
    ]

    for (idx, testCase) in enumerate(testCases)
        println("\n--- Modèle $idx ---")
        println("lignes  = ", testCase.lignes)
        println("colonnes= ", testCase.colonnes)
        gridSolver(testCase.lignes, testCase.colonnes)
    end
end

function main()
    # Exemple d'utilisation avec des contraintes sur le nombre de cases noires par ligne et par colonne
    # gridSolver([5,3,3,5,2], [5,5,2,2,4])
    # gridSolver([4,5,3,3,3],[3,4,3,3,5])
    # gridSolver([3,5,2,5,3],[3,2,4,5,4])
    gridSolver([3, 4, 5, 4, 2], [4, 4, 3, 3, 4]) #SOUS TOUR
    # gridSolver([3,4,3,2,6,2],[4,4,2,3,2,5])
    # gridSolver([4,5,5,2,5,5],[4,5,4,5,5,3])


end

main()
