@testset "Bitstream" begin
    x = SBitstream(0.5)
    xbit = pop!(x)

    @test (push!(x, xbit); true)
    @test observe(x) == xbit
    @test pop!(x) == xbit
end