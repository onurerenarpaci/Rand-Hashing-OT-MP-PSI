include("utils.jl")
include("aggregator_lib.jl")
include("client_lib.jl")

using FileIO
using BenchmarkTools
using JSON
using JLD2

const K, r, Repeat = rint(PRIME), rint(PRIME), 20

function share_creation(ip_lists::Vector{Vector{Int}}, M::Int, N::Int, t::Int)
    println("share creation")
    mkpath("inter_data")
    Threads.@threads for i in 1:N
        share_array, _ = create_share_array(ip_lists[i], NumType(i), K, r, M, Repeat, t, PRIME)
        save("inter_data/share_array_" * string(i) * ".jld2", "share_array", share_array)
    end
    println("share construction done")
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--Input", "-i"
            help = "Input file name"
            arg_type = String
            default = "benchmark-reconstruction-N-t-eq.json"
    end

    return parse_args(s)
end

function main()

    parsed_args = parse_commandline()
    benchmark_file_name = replace(parsed_args["Input"], ".json" => "")
    #open json file
    benchmark_input::Vector{Any} = JSON.parsefile("benchmark_input/" * benchmark_file_name * ".json")

    mkpath("benchmark_output")
    benchmark_res::Vector{Any} = []
    if isfile("benchmark_output/" * benchmark_file_name * "-results" * ".json")
        benchmark_res = JSON.parsefile("benchmark_output/" * benchmark_file_name * "-results" * ".json")
    end
    starting_point = length(benchmark_res) + 1

    for benc_i in starting_point:length(benchmark_input)
        params = benchmark_input[benc_i]
        M::Int = params["M"]
        N::Int = params["N"]
        t::Int = params["t"]

        println("Benchmarking with M = ", M, ", N = ", N, ", t = ", t)


        ip_lists = get_ip_lists_benchmark(N, M)

        share_creation(ip_lists, M, N, t)

        share_array_list::Array{UInt128, 3} = Array{UInt128, 3}(undef, M*t, Repeat, N)
        for i in 1:N
            share_array_list[:, :, i] = load("inter_data/share_array_" * string(i) * ".jld2")["share_array"]
        end

        bench_res = @benchmark reconstruction($share_array_list, $M, $N, $t, $Repeat) samples=100 seconds=5
        display(bench_res)
        println(mean(bench_res).time)

        #save results
        params["mean_time"] = mean(bench_res).time
        params["median_time"] = median(bench_res).time
        params["std_time"] = std(bench_res).time
        
        params["times"] = bench_res.times

        push!(benchmark_res, params)

        #save intermed_res
        open("benchmark_output/" * benchmark_file_name * "-results" * ".json", "w") do json_file
            JSON.print(json_file, benchmark_res)
        end
    end

    #save results
    open("benchmark_output/" * benchmark_file_name * "-results" * ".json", "w") do json_file
        JSON.print(json_file, benchmark_res)
    end
end

main()