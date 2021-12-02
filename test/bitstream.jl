@testset "Bitstream" begin
    x = SBitstream(0.5)
    xbit = pop!(x)
    push!(x, xbit)

    @test observe(x) == xbit
    @test length(x) == 1
    @test x[1] == xbit
    @test pop!(x) == xbit
end
