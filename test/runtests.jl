using BitSAD
using Test
using Statistics: mean

@testset "Bitstream" begin
    x = SBitstream(0.5)
    xbit = pop!(x)

    @test (push!(x, xbit); true)
    @test observe(x) == xbit
    @test pop!(x) == xbit
end

@testset "SBitstream" begin
    x = SBitstream(0.5)
    y = SBitstream(0.1)
    X = SBitstream(fill(0.5, 2, 2))
    Y = SBitstream(fill(0.5, 2, 2))

    @testset "FP Values" begin
        @test x.value == 0.5 && y.value == 0.1
        @test (x + y).value == x.value + y.value
        @test (x - y).value == x.value - y.value
        @test (x * y).value == x.value * y.value
        @test (y / x).value == y.value / x.value
        @test_logs (:warn, "SBitstream can only be ∈ [-1, 1] (saturation occurring).") (x / y).value == 1
        @test (x ÷ 2).value == 0.25
        @test_throws ErrorException x ÷ 0.2
        @test sqrt(x).value == sqrt(x.value)
        @test decorrelate(x).value == x.value
        @test map(λ -> λ.value, X * Y) == map(λ -> λ.value, X) * map(λ -> λ.value, Y)
    end

    @testset "Sample Generation" begin
        xbits = generate(x, 100000)
        @test mean(map(xbit -> pos(xbit) - neg(xbit), xbits)) ≈ x.value atol = 0.01
    end

    @testset "Bit-Level Ops" begin
        T = 30000
        @testset for op in (+, -, *, /, ÷)
            if op == ÷
                @test begin
                    z = 0
                    for t in 1:T
                        bit = pop!(op(x, 2))
                        z += pos(bit) - neg(bit)
                    end

                    z / T
                end ≈ op(x, 2).value atol = 0.01
            elseif op == /
                @test begin
                    z = 0
                    for t in 1:T
                        bit = pop!(op(y, x))
                        z += pos(bit) - neg(bit)
                    end

                    z / T
                end ≈ op(y, x).value atol = 0.01
            else
                @test begin
                    z = 0
                    for t in 1:T
                        bit = pop!(op(x, y))
                        z += pos(bit) - neg(bit)
                    end

                    z / T
                end ≈ op(x, y).value atol = 0.01
                @test begin
                    z = 0
                    for t in 1:T
                        bit = pop!(op(y, x))
                        z += pos(bit) - neg(bit)
                    end

                    z / T
                end ≈ op(y, x).value atol = 0.01
            end
        end
        @testset for op in (sqrt, decorrelate)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(op(x))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ op(x).value atol = 0.01
        end
        @testset "op = * (matrix)" begin
            @test all(isapprox.(begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(X * Y)
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end, map(λ -> λ.value, X * Y); atol = 0.01))
            @test all(isapprox.(begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(Y * X)
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end, map(λ -> λ.value, Y * X); atol = 0.01))
        end
    end
end