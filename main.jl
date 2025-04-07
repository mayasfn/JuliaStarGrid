#using JuMP,HiGHS
using JuMP,Cbc

function gridSolver(lignes::Array{Int64},colonnes::Array{Int64})
    n = size(lignes,1)

    #model = Model(HiGHS.Optimizer)
    model = Model(Cbc.Optimizer)

    @variable(model,x[1:n,1:n],Bin) #grille
    
    @variable(model,y[1:n,1:n,3,3],Bin) #direction 

    @objective(model,Max,0)
    # pttr des variable pour les directions
    @constraint(model,verticale[i in 1:n],sum(x[i,k] for k in 1:n) == lignes[i]) #pour les lignes
    @constraint(model,horizontale[j in 1:n],sum(x[k,j] for k in 1:n) == colonnes[j]) #pour les colonnes
    
    # three stars per cell for y[i,j][starscells] where x[i,j]==1
    @constraint(model, [i in 1:n, j in 1:n], sum(y[i,j,k,l] for k in 1:3, l in 1:3) == 3 * x[i,j])

    # if x[i,j] == 1 and x[i+1,j]==1 then in y[i,j,2,3]==1 -> top
    @constraint(model, [i in 1:n-1, j in 1:n], y[i,j,2,3] >= x[i,j] + x[i+1,j] - 1)

    # if x[i,j]==1 then y[i,j,2,2]==1 -> center cell
    @constraint(model, [i in 1:n, j in 1:n], y[i,j,2,2] == x[i,j])

    # if x[i,j] == 1 and x[i-1,j]==1 then in y[i,j,2,1]==1 -> bottom
    @constraint(model, [i in 2:n, j in 1:n], y[i,j,2,1] >= x[i,j] + x[i-1,j] - 1)

    # if x[i,j] == 1 and x[i,j+1]==1 then in y[i,j,1,2]==1 -> left cell
    @constraint(model, [i in 1:n, j in 2:n], y[i,j,3,2] >= x[i,j] + x[i,j-1] - 1)

    # if x[i,j] == 1 and x[i,j-1]==1 then in y[i,j,3,2]==1 -> right cell
    @constraint(model, [i in 1:n, j in 1:n-1], y[i,j,1,2] >= x[i,j] + x[i,j+1] - 1)

    # pour les directions
    # faut pas que l'entree et la sortie soient le smemes
    # faut pas avoir une sortie en diagonale

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