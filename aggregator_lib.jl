using Combinatorics

function reconstruction(share_array_list::Array{UInt128, 3}, M::Int, N::Int, t::Int, Repeat::Int)
    combs = collect(combinations(NumType(1):NumType(N), t))

    final_res::Array{Set{UInt128}, 2} = Array{Set{UInt128}, 2}(undef, Repeat, N)
    for i in 1:Repeat
        for j in 1:N
            final_res[i, j] = Set{UInt128}()
        end
    end
    intermed_res::Array{Vector{UInt128}, 2} = Array{Vector{UInt128}, 2}(undef, Repeat, length(combs))

    coeffs_ex_thread::Array{NumType, 3} = Array{NumType, 3}(undef, M*t, t, Threads.nthreads())
    res_thread::Array{NumType, 2} = Array{NumType, 2}(undef, M*t, Threads.nthreads())
  
    Threads.@threads for x_i in eachindex(combs)
        x_comb = combs[x_i]

        coeffs = calculate_coefficients(x_comb, PRIME)
        coeffs_ex = @view coeffs_ex_thread[:, :, threadid()]
        for i in 1:t
            coeffs_ex[:, i] .= coeffs[i]
        end

        res = @view res_thread[:, threadid()]
        for i in 1:Repeat
            shares = @view share_array_list[:, i, x_comb]
            recover_secret(shares, coeffs_ex, res, PRIME, t)
            intermed_res[i, x_i] = findall(x -> x == NumType(0), (@view res[:,1]))
        end
    end

    for x_i in eachindex(combs)
        for i in 1:Repeat
            union!(final_res[i, combs[x_i][1]], intermed_res[i, x_i])
        end
    end
    return final_res
end