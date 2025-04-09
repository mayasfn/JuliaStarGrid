using JuMP, HiGHS
# using JuMP, Cbc

function gridSolver(lignes::Vector{Int}, colonnes::Vector{Int})
    n = length(lignes)

    model = Model(HiGHS.Optimizer)
    # model = Model(Cbc.Optimizer)

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
        up[i,j] + down[i,j] + left[i,j] + right[i,j] <= 2 * x[i,j]
    )

    # 3) Exemples de contraintes de cohérence entre directions opposées
    @constraint(model, [i in 2:n, j in 1:n], up[i,j] <= down[i-1,j])
    @constraint(model, [i in 2:n, j in 1:n], down[i-1,j] <= up[i,j])
    @constraint(model, [i in 1:n, j in 1:(n-1)], right[i,j] <= left[i,j+1])
    @constraint(model, [i in 1:n, j in 1:(n-1)], left[i,j+1] <= right[i,j])

    # La modélisation complète ajouterait ici d'autres contraintes 
    # (par exemple pour imposer un unique chemin connecté, etc.).

    @objective(model, Min, 0)  # Pas de critère d'optimisation particulier

    optimize!(model)

    if termination_status(model) != MOI.OPTIMAL
        println("Pas de solution optimale trouvée.")
        return -1
    end

    x_sol = round.(Int, value.(x))
    displayGrid(x_sol)
    return 0
end

"""
    displayGrid(x_sol)

Affiche la grille solution sous forme de tableau encadré, similaire à l'affichage demandé dans l'exercice.
Une case noire est représentée par " * " et une case vide par des espaces.
"""
function displayGrid(x_sol::Array{Int,2})
    n = size(x_sol, 1)
    
    # Construit la ligne de séparation (ex: "+---+---+---+")
    function separator_line(n)
        # Concatène n segments de '---' séparés par des '+'
        return "+" * join(fill("---", n), "+") * "+"
    end
    
    sep = separator_line(n)
    println(sep)
    for i in 1:n
        row_str = "|"  # début de la ligne
        for j in 1:n
            cell = if x_sol[i,j] == 1
                " * "
            else
                "   "
            end
            row_str *= cell * "|"
        end
        println(row_str)
        println(sep)
    end
end

function main()
    # Exemple d'utilisation avec des contraintes sur le nombre de cases noires par ligne et par colonne
    gridSolver([5,3,3,5,2], [5,5,2,2,4])
end

main()
