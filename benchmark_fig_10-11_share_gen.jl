include("utils.jl")
include("client_lib.jl")

using FileIO
using BenchmarkTools
using JSON

const K, r, Repeat = rint(PRIME), rint(PRIME), 20

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--Input", "-i"
            help = "Input file name"
            arg_type = String
            default = "benchmark-reconstruction-share-gen.json"
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

        bench_res = @benchmark create_share_array($ip_lists[i], $NumType(i), $K, $r, $M, $Repeat, $t, PRIME) setup=(i = rint(NumType($N-1))+1) samples=20 seconds=300

        #save results
        params["mean_time"] = mean(bench_res).time
        params["median_time"] = median(bench_res).time

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