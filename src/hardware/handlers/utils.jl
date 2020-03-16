handlebroadcast(lhs::Symbol, rhs::Symbol, lsize::Tuple{Int, Int}, rsize::Tuple{Int, Int}) =
    lsize == (1, 1) ? (suffix -> "{$(rsize[1] * rsize[2]){$(lhs)$suffix}}", suffix -> "$(rhs)$suffix", rsize) :
    rsize == (1, 1) ? (suffix -> "$(lhs)$suffix", suffix -> "{$(lsize[1] * lsize[2]){$(rhs)$suffix}}", lsize) :
    (suffix -> "$(lhs)$suffix", suffix -> "$(rhs)$suffix", lsize)