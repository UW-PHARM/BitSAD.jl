handle_broadcast_name(names, sizes, finalsize) = map(zip(names, sizes)) do (name, sz)
        (sz == (1, 1)) ? suffix -> "{$(join(finalsize, "*")){$(name)$suffix}}" :
                         suffix -> "$(name)$suffix"
end

handle_broadcast_name(lhs::String, rhs::String, lsize, rsize) =
    (lsize == (1, 1)) && (rsize == (1, 1)) ? (suffix -> "$(lhs)$suffix", suffix -> "$(rhs)$suffix") :
    lsize == (1, 1) ? (suffix -> "{$(rsize[1] * rsize[2]){$(lhs)$suffix}}",
                       suffix -> "$(rhs)$suffix") :
    rsize == (1, 1) ? (suffix -> "$(lhs)$suffix",
                       suffix -> "{$(lsize[1] * lsize[2]){$(rhs)$suffix}}") :
    (suffix -> "$(lhs)$suffix", suffix -> "$(rhs)$suffix")
