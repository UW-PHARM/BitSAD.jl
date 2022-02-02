handle_broadcast_name(names, sizes, finalsize) = map(zip(names, sizes)) do (name, sz)
    sz = (sz..., ntuple(() -> 1, length(finalsize) - length(sz))...)
    if sz == finalsize
        return suffix -> "$(name)$suffix"
    else
        return suffix -> begin
            outname = "$(name)$suffix"
            for (s, sf) in zip(sz, finalsize)
                outname = "{($sf / $s){$outname}}"
            end

            return outname
        end
    end
end

handle_broadcast_name(lhs::String, rhs::String, lsize, rsize) =
    (lsize == (1, 1)) && (rsize == (1, 1)) ? (suffix -> "$(lhs)$suffix", suffix -> "$(rhs)$suffix") :
    lsize == (1, 1) ? (suffix -> "{$(rsize[1] * rsize[2]){$(lhs)$suffix}}",
                       suffix -> "$(rhs)$suffix") :
    rsize == (1, 1) ? (suffix -> "$(lhs)$suffix",
                       suffix -> "{$(lsize[1] * lsize[2]){$(rhs)$suffix}}") :
    (suffix -> "$(lhs)$suffix", suffix -> "$(rhs)$suffix")

function write_for_loop(buffer, index_name, sz_name, stride, write_body, padding = 0)
    maybesz = tryparse(Int, sz_name)
    if isnothing(maybesz) || (maybesz < 10)
        write(buffer, repeat(" ", padding))
        write(buffer, "for ($index_name = 0; $index_name < $sz_name; $index_name = $index_name + $stride) begin : $(index_name)_gen\n")
        write_body(buffer, index_name, padding + 1)
        write(buffer, repeat(" ", padding))
        write(buffer, "end")
    else
        index_name_blk = index_name * "_blk"
        write(buffer, repeat(" ", padding))
        write(buffer, "for ($index_name_blk = 0; $index_name_blk < $maybesz / 10; $index_name_blk = $index_name_blk + 1) begin : $(index_name_blk)_gen\n")
        write(buffer, repeat(" ", padding + 1))
        write(buffer, "for ($index_name = $index_name_blk * 10; $index_name < 10; $index_name = $index_name + $stride) begin : $(index_name)_gen\n")
        write_body(buffer, index_name, padding + 2)
        write(buffer, repeat(" ", padding + 1))
        write(buffer, "end")
        write(buffer, repeat(" ", padding))
        write(buffer, "end")
    end
end

function write_bcast_instantiation(buffer, prefix, outsize, body)
    write(buffer, """
        genvar $(join(ntuple(i -> "$(prefix)_i_$i", length(outsize)), ", "));

        generate
        """)

    padding = 0
    for sz in outsize
        
    for (i, sz) in enumerate(outsize)
        write(buffer, repeat(" ", i - 1) * "for ($(prefix)_i_$i = 0; $(prefix)_i_$i < $sz; $(prefix)_i_$i = $(prefix)_i_$i + 1) begin : $(prefix)_gen_$i\n")
    end
    write(buffer, repeat(" ", length(outsize)) * "localparam $(prefix)_i = ")
    write(buffer, join(ntuple(i -> "$(prefix)_i_$i * $(join(outsize[(i + 1):end], "*"))", length(outsize) - 1), " + "))
    write(buffer, " + $(prefix)_i_$(length(outsize));\n")
    for line in split(body, "\n"; keepempty = true)
        write(buffer, repeat(" ", length(outsize)) * line * "\n")
    end
    for i in length(outsize):-1:1
        write(buffer, repeat(" ", i - 1) * "end\n")
    end
    write(buffer, "endgenerate\n")
end
