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
        share_array, encrypted_ips = create_share_array(ip_lists[i], NumType(i), K, r, M, Repeat, t, PRIME)
        save("inter_data/encrypted_ips_" * string(i) * ".jld2", "encrypted_ips", encrypted_ips)
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

    # -- Filtering the encrypted elements whose shares succesfully reconstructed -- Happens in aggregator --
    filtered_encrypted_ip_list::Vector{Vector{UInt8}} = []
    @timeit to "filter" begin
    for i in 1:N
        encrypted_ips = load("inter_data/encrypted_ips_" * string(i) * ".jld2")["encrypted_ips"]
        for j in 1:Repeat
            append!(filtered_encrypted_ip_list, eachcol(encrypted_ips[:, collect(res_idx[j,i]), j]))
        end
    end
    end

    # -- Decrypting the results -- Happens in participants --
    @timeit to "decrypt" decrypted_ip_list = [decrypt_element([K, r], x) for x in filtered_encrypted_ip_list]
    
    # -- Deduplicating the results -- Happens in participants --
    @timeit to "deduplicate" intersec = sort(collect(Int, Set(decrypted_ip_list)))
    
    println("Protocol finished")
    println("Over threshold intersection size: ", length(intersec))
    display(to)
end

main()