include("utils.jl")
include("client_lib.jl")

using CSV
using DataFrames

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--M", "-m"
            help = "Number of elements each participant has"
            arg_type = Int
            default = 200
        "--Trials", "-r"
            help = "Number of trials"
            arg_type = Int
            default = 10_000_000
        "-t"
            help = "The threshold value"
            arg_type = Int
            default = 3
    end

    return parse_args(s)
end

parsed_args = parse_commandline()

exp_one = 0.2477425387
reps = collect(2:20)
trials = parsed_args["Trials"]
t = parsed_args["t"]
M = parsed_args["M"]
result = []
expected = [(exp_one^i)*trials for i in reps]

for i in eachindex(reps)
    
    accumulate = Threads.Atomic{Int}(0)
    Threads.@threads for j in 1:div(trials,M)
        misses = simulate_share_array(NumType(M), NumType(t), NumType(reps[i]))
        Threads.atomic_add!(accumulate, misses)
    end
    
    push!(result, accumulate[])
    display(result)
    df = DataFrame(reps = reps[1:i], result = result, expected = expected[1:i])
    
    mkpath("benchmark_output")
    CSV.write("benchmark_output/missed-intersections.csv", df)
end

