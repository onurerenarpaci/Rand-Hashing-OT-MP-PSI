include("utils.jl")
include("client_lib.jl")
include("aggregator_lib.jl")

using TimerOutputs
using FileIO

const K, r, Repeat = rint(PRIME), rint(PRIME), 20

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--M", "-m"
            help = "Number of elements each participant has"
            arg_type = Int
            default = 100
        "--N", "-n"
            help = "Number of participants"
            arg_type = Int
            default = 10
        "-t"
            help = "The threshold value"
            arg_type = Int
            default = 3
    end

    return parse_args(s)
end

function share_creation(ip_lists::Vector{Vector{Int}}, M::Int, N::Int, t::Int)
    println("share creation")
    mkpath("inter_data")
    Threads.@threads for i in 1:N
        share_array, plain_array = create_share_array(ip_lists[i], NumType(i), K, r, M, Repeat, t, PRIME)
        save("inter_data/plain_array_" * string(i) * ".jld2", "plain_array", plain_array)
        save("inter_data/share_array_" * string(i) * ".jld2", "share_array", share_array)
    end
    println("share construction done")
end

function main()

    to = TimerOutput()
    parsed_args = parse_commandline()

    M = parsed_args["M"]
    N = parsed_args["N"]
    t = parsed_args["t"]

    ip_lists= get_ip_lists_benchmark(N, M)

    println("Number of threads: ", Threads.nthreads())
    println("M: ", M)
    println("N: ", N)
    println("t: ", t)

    # -- Share creation -- Happens in participants --
    @timeit to "create_shares" share_creation(ip_lists, M, N, t)

    share_array_list::Array{UInt128, 3} = Array{UInt128, 3}(undef, M*t, Repeat, N)
    for i in 1:N
        share_array_list[:, :, i] = load("inter_data/share_array_" * string(i) * ".jld2")["share_array"]
    end

    # -- Reconstruction -- Happens in aggregator --
    println("reconstruction")
    @timeit to "reconstruction" res_idx = reconstruction(share_array_list, M, N, t, Repeat)
    println("reconstruction done")

    # -- Filtering the elements whose shares succesfully reconstructed -- Happens in participants --
    filtered_plain_ip_list::Vector{Int} = []
    @timeit to "filter" begin
    for i in 1:N
        plain_array = load("inter_data/plain_array_" * string(i) * ".jld2")["plain_array"]
        for j in 1:Repeat
            append!(filtered_plain_ip_list, collect(plain_array[collect(res_idx[j,i]), j]))
        end
    end
    end
    
    # -- Deduplicating the results -- Happens in participants --
    @timeit to "deduplicate" intersec = sort(collect(Int, Set(filtered_plain_ip_list)))
    
    println("Protocol finished")
    println("Over threshold intersection size: ", length(intersec))
    display(to)
end

main()