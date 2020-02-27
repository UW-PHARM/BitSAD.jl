@testset "DBitstream" begin
    @testset "DBit" begin
        @test zero(DBit) == DBit(false)
        @test one(DBit) == DBit(true)
        @test float(DBit(true)) == 1
        @test float(DBit(false)) == -1
    end

    x = DBitstream()
    y = DBitstream()

    push!(x, DBit(true))
    push!(y, DBit(false))
    @test float(pop!(x)) == 1
    @test float(pop!(y)) == -1

    ops = (+, -, *, /)
    xstream = [DBit(i) for i in rand(Bool, length(ops) * 2)]
    ystream = [DBit(i) for i in rand(Bool, length(ops) * 2)]
    push!(x, xstream)
    push!(y, ystream)
    i = 1
    xstream = float.(xstream)
    ystream = float.(ystream)
    @testset for op in ops
        z = rand(Float64)
        @test op(pop!(x), pop!(y)) == op(xstream[i], ystream[i])
        @test op(pop!(x), z) == op(xstream[i + 1], z)
        @test op(z, pop!(y)) == op(z, ystream[i + 1])
        i += 2
    end
end