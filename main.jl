using JuMP,HiGHS
# using JuMP,Cbc

function gridSolver(lignes::Array{Int64},colonnes::Array{Int64})
    n = size(lignes,1)

    model = Model(HiGHS.Optimizer)

    @variable(model,x[1:n,1:n],Bin)

    @objective(model,Max,0)
    # pttr des variable pour les directions
    # @constraint(model,verticale[i in 1:n,k in 1:n],sum(x[i,k])<= lignes[i]) #pourune ligne
    # @constraint(model,horizontale[j in 1:n,k in 1:n],sum(x[k,j])<= colonnes[j]) #pourune horizontale

    optimize!(model)

    if termination_status(model) != MOI.OPTIMAL return -1 end
end

function main()
    gridSolver([5,5,2,2,4],[5,3,3,5,2])
end

main()