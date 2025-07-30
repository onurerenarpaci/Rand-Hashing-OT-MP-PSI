using Random
using SHA
using JSON
using ProgressMeter
using FileIO
using Base.Threads
using ArgParse

const NumType::Type = UInt128 #typeof(BigInt(1))
const PRIME::NumType = NumType(2)^61 - 1
const ELEMENT_HASH_SIZE::NumType = NumType(2)^32

function rint(x::NumType)
    rand(RandomDevice(), 0:x)
end

function hash_func(data_list::Vector{NumType}, mod_num::NumType) :: NumType

    byte_data = reinterpret(UInt8, data_list)
    hash = sha256(byte_data)

    return reinterpret(NumType, hash)[1] % mod_num
end

# shamir start
function _eval_at(poly::Array{NumType}, x::NumType, prime::NumType)::NumType
    accum = NumType(0)
    for i in length(poly):-1:1
        accum *= x
        accum += poly[i]
        accum %= prime
    end
    return accum
end

function create_share(x::NumType, secret::NumType, keys::Vector{NumType}, threshold::Integer, prime::NumType)::NumType
    current_hash::NumType = hash_func([keys..., secret], prime)
    poly = [NumType(0), current_hash]
    for i in 1:threshold-2
        current_hash = hash_func([current_hash], prime)
        poly = vcat(poly, current_hash)
    end

    return _eval_at(poly, x, prime)
end

function create_share_list(x::NumType, secrets::Vector{NumType}, keys::Vector{NumType}, threshold::Integer, prime::NumType)::Vector{NumType}

    shares = Vector{NumType}(undef, length(secrets))
    for i in 1:length(secrets)
        shares[i] = create_share(x, secrets[i], keys, threshold, prime)
    end
    
    return shares
end

function _divmod(a::NumType, b::NumType, prime::NumType)
    inv = Base.invmod(b, prime)
    return mod.(a * inv, prime)
end

function mulmod(a::NumType, b::NumType)
    return mod(a * b, PRIME)
end

function calculate_coefficients(x_list::Vector{NumType}, prime::NumType)
    k = length(x_list)
    if k != length(Set(x_list))
        throw(ArgumentError("x_list must contain unique elements"))
    end

    nums = Vector{NumType}()
    dens = Vector{NumType}()

    for i in 1:k
        others = vcat(x_list[1:i-1], x_list[i+1:end])
        push!(nums, reduce(*, others))
        push!(dens, reduce(mulmod, [x + (prime - x_list[i]) for x in others]))
    end
    nums = mod.(nums, prime)
    dens = mod.(dens, prime)
    return [_divmod(nums[i], dens[i], prime) for i in 1:k]  
end

@inline function mersenne_mod(k::UInt128, p::UInt128)
    i = (k & p) + (k >> 61)
    return (i >= p) ? i - p : i
end

function recover_secret(
    y_list::SubArray{UInt128, 2, Array{UInt128, 3}, Tuple{Base.Slice{Base.OneTo{Int64}}, Int64, Vector{UInt128}}, false}, 
    coeffs::SubArray{UInt128, 2, Array{UInt128, 3}, Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64}, true}, 
    res::SubArray{UInt128, 1, Matrix{UInt128}, Tuple{Base.Slice{Base.OneTo{Int64}}, Int64}, true},
    prime::NumType,
    t::Int)

    #first iteration
    for j in eachindex(res)
        @inbounds res[j] = y_list[j, 1] * coeffs[j, 1]
        @inbounds res[j] = mersenne_mod(res[j], prime)
    end
    #rest
    for i in 2:t
        for j in eachindex(res)
            @inbounds res[j] += y_list[j, i] * coeffs[j, i]
            @inbounds res[j] = mersenne_mod(res[j], prime)
        end
    end

end

function ip_to_int(ip::String)::Int
    parts = split(ip, '.')
    return (parse(Int, parts[1]) << 24) + (parse(Int, parts[2]) << 16) + (parse(Int, parts[3]) << 8) + parse(Int, parts[4])
end

function int_to_ip(ip::Int)::String
    return string((ip >> 24) & 0xff, '.', (ip >> 16) & 0xff, '.', (ip >> 8) & 0xff, '.', ip & 0xff)
end

function get_ip_lists_benchmark(N::Int, M::Int)::Vector{Vector{Int}}
    ip_lists::Vector{Vector{Int}} = [[] for _ in 1:N]
    for i in 1:N
        for j in 1:M
            push!(ip_lists[i], rint(NumType(M*N)))
        end
    end
    return ip_lists
end