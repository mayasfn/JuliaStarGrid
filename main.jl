using JuMP,HiGHS
# using JuMP,Cbc

function gridSolver(lignes::Array{Int64},colonnes::Array{Int64})
    n = size(lignes,1)

    model = Model(HiGHS.Optimizer)
    #model = Model(Cbc.Optimizer)

    @variable(model,x[1:n,1:n],Bin)

    @objective(model,Max,0)
    # pttr des variable pour les directions
    @constraint(model,verticale[i in 1:n],sum(x[i,k] for k in 1:n) == lignes[i]) #pour les lignes
    @constraint(model,horizontale[j in 1:n],sum(x[k,j] for k in 1:n) == colonnes[j]) #pour les colonnes
    

    # pour les directions
    # faut pas que l'entree et la sortie soient le smemes
    # faut pas avoir une sortie en diagonale
    # les entrees ou sorties sont : Up,Down,Left,Right

    optimize!(model)

    if termination_status(model) != MOI.OPTIMAL return -1 end

    x_sol = round.(Int64,value.(x))
    println("Il y'a ",round(Int64,n*n-objective_value(model))," cases libres")
    for i in 1:n
        for j in 1:n
            print("|")
            if (x_sol[i,j]==1) print(" * ")
            else print("   ")
            end
        end
        print("|")
        print("\n")
    end
end

function main()
    gridSolver([5,3,3,5,2],[5,5,2,2,4])
end

main()