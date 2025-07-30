include("utils.jl")
using Nettle

const enc_lock = ReentrantLock()

function aes_key_from_numbers(keys::Vector{NumType})
    if Base.hastypemax(NumType)
        byte_data = reinterpret(UInt8, keys)
        hash = sha256(byte_data)
    else
        byte_data = Vector{UInt8}()
        for data in keys
            byte_data = vcat(byte_data, digits(UInt8, data; base=256))
        end
        hash = sha256(byte_data)
    end
    return hash
end

function encrypt_element(keys::Vector{NumType}, data::NumType)::Vector{UInt8}
    key32 = aes_key_from_numbers(keys)
    encryptor = Encryptor("AES256", key32)
    iv16 = rand(UInt8, 16)
    data_bytes = reinterpret(UInt8, [data])
    encrypted_data = encrypt(encryptor, :CBC, iv16, data_bytes)
    return vcat(iv16, encrypted_data)
end

function encrypt_element!(encryptor::Encryptor, data::NumType, result::SubArray{UInt8, 1, Array{UInt8, 3}, Tuple{Base.Slice{Base.OneTo{Int64}}, Int64, Int64}, true})
    rand!(result)
    encrypted_data = encrypt!(encryptor, :CBC, Vector{UInt8}(view(result, 1:16)), view(result, 17:32) , [data])
end

function decrypt_element(keys::Vector{NumType}, data::Vector{UInt8})
    key32 = aes_key_from_numbers(keys)
    decryptor = Decryptor("AES256", key32)
    decrypted_data = decrypt(decryptor, :CBC, data[1:16], data[17:end])
    return reinterpret(NumType, decrypted_data)[1]
end

function simulate_share_array(M::NumType, t::NumType, Repeat::NumType)
    B = M*t
    seed = rint(PRIME)
    seed2 = rint(PRIME)
    share_arr::Array{NumType, 3} = zeros(NumType, (B, Repeat, t))
    order_arr::Array{NumType, 2} = zeros(NumType, (B, Repeat))

    ip_hashes::Array{NumType, 2} = Array{NumType, 2}(undef, M, t)
    for i in 1:M
        for j in 1:t
            ip_hashes[i, j] = rint(PRIME)
        end
    end

    for p in 1:t
        for ri in 1:Repeat
            #first insertion
            for mi in 1:M
                idx = hash_func([ri, ip_hashes[mi, p], seed], B) + 1
                hash_order = hash_func([(ri÷NumType(2)), ip_hashes[mi, p], seed], PRIME)
                if  ( ( order_arr[idx, ri] == 0 ) || 
                    ( (order_arr[idx, ri] < hash_order) && (ri % 2 == 0) ) || 
                    ( (order_arr[idx, ri] > hash_order) && (ri % 2 == 1) ))
                    share_arr[idx, ri, p] = ip_hashes[mi, p]
                    order_arr[idx, ri] = hash_order
                end
            end
            #second insertion
            for i in eachindex(order_arr)
                order_arr[i] = NumType(0)
            end

            for mi in 1:M
                idx = hash_func([ri, ip_hashes[mi, p], seed2], B) + 1
                hash_order = hash_func([(ri÷NumType(2)), ip_hashes[mi, p], seed], PRIME)
                if  ( share_arr[idx, ri, p] == 0) && 
                    ( ( order_arr[idx, ri] == 0 ) || 
                    ( (order_arr[idx, ri] < hash_order) && (ri % 2 == 1) ) || 
                    ( (order_arr[idx, ri] > hash_order) && (ri % 2 == 0) ))
                    share = create_share(p, ip_hashes[mi, p], [p, ri], t, PRIME)
                    share_arr[idx, ri, p] = share
                    order_arr[idx, ri] = hash_order
                end
            end       
        end
    end

    ip_sets::Array{Set{NumType}, 1} = Array{Set{NumType}, 1}(undef, t)
    for i in 1:t
        ip_sets[i] = Set(ip_hashes[:, i])
    end
    
    share_sets::Array{Set{NumType}, 2} = Array{Set{NumType}, 2}(undef, Repeat, t)
    for i in 1:Repeat
        for j in 1:t
            share_sets[i, j] = Set(share_arr[:, i, j])
        end
    end

    for i in 1:Repeat
        for j in 1:t
            share_sets[i, j] = setdiff(ip_sets[j], share_sets[i, j])
        end
    end

    missing_shares::Array{Set{NumType}, 1} = Array{Set{NumType}, 1}(undef, Repeat)
    for i in 1:Repeat
        missing_shares[i] = Set{NumType}()
        for j in 1:t
            union!(missing_shares[i], share_sets[i, j])
        end
    end

    missing_all::Set{NumType} = missing_shares[1]
    for i in 2:Repeat
        intersect!(missing_all, missing_shares[i])
    end

    return length(missing_all)
end

function create_share_array(ips::Vector{Int}, participant_id::NumType, K::NumType, r::NumType, M::Integer, Repeat::Integer, threshold::Integer, prime::NumType)
    B = NumType(M*threshold)

    share_arr::Array{NumType, 2} = zeros(NumType, (B, Repeat))
    order_arr::Array{NumType, 2} = zeros(NumType, (B, Repeat))
    encrypted_arr::Array{UInt8, 3} = Array{UInt8}(undef, 32, B, Repeat)

    ip_hashes::Array{NumType, 1} = Array{NumType, 1}(undef, length(ips))
    for i in 1:length(ips)
        ip_hashes[i] = hash_func([K, r, NumType(ips[i])], PRIME)
    end

    key32 = aes_key_from_numbers([K, r])

    local encryptor
    lock(enc_lock)
    try
        encryptor = Encryptor("AES256", key32)
    finally
        unlock(enc_lock)
    end
    
    for ri in 1:Repeat
        
        is_even = (ri % 2 == 0)
        #first insertion
        for mi in 1:length(ips)
            ip_hash = ip_hashes[mi]
            idx = hash_func([K, r, ri, ip_hash], B) + 1
            hash_order = hash_func([K, r, (ri÷NumType(2)), ip_hash], PRIME)
            prev_order = order_arr[idx, ri]
            if  ( ( prev_order == 0 ) || 
                ( (prev_order < hash_order) == is_even ) )
                share_arr[idx, ri] = create_share(participant_id, ip_hash, [K, r, ri], threshold, prime)
                encrypt_element!(encryptor, NumType(ips[mi]), @view encrypted_arr[:, idx, ri])
                order_arr[idx, ri] = hash_order
            end
        end

        #second insertion
        for i in eachindex(order_arr)
            order_arr[i] = NumType(0)
        end

        hash_seed = rint(PRIME)
        for mi in 1:length(ips)
            ip_hash = ip_hashes[mi]
            idx = hash_func([K, r, ri, hash_seed, ip_hash], B) + 1
            hash_order = hash_func([K, r, (ri÷NumType(2)), ip_hash], PRIME)
            prev_order = order_arr[idx, ri]
            if  ( share_arr[idx, ri] == 0) && 
                ( ( prev_order == 0 ) || 
                ( (prev_order > hash_order) == is_even ))
                share_arr[idx, ri] = create_share(participant_id, ip_hash, [K, r, ri], threshold, prime)
                encrypt_element!(encryptor, NumType(ips[mi]), @view encrypted_arr[:, idx, ri])
                order_arr[idx, ri] = hash_order
            end
        end       
    end

    #add dummy shares
    for ri in 1:Repeat
        for mi in 1:B
            if share_arr[mi, ri] == 0
                share_arr[mi, ri] = rint(prime)
                rand!(@view encrypted_arr[:, mi, ri])
            end
        end
    end

    return share_arr, encrypted_arr
end