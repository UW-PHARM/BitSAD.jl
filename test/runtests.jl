using BitSAD
using Test
using Statistics: mean
using LinearAlgebra: norm

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
    w = SBitstream(-0.1)
    X = SBitstream(0.5 * rand(2, 2))
    Y = SBitstream(-0.5 * rand(2, 2))
    v = SBitstream([0.5 * rand(), -0.5 * rand()])

    @testset "FP Values" begin
        @test x.value == 0.5 && y.value == 0.1
        @test float(x) == x.value
        @testset for op in (+, -, *)
            @test op(x, y).value == op(x.value, y.value)
            @test op(x, w).value == op(x.value, w.value)
        end
        @test (y / x).value == y.value / x.value
        @test_logs (:warn, "SBitstream can only be ∈ [-1, 1] (saturation occurring).") (x / y).value == 1
        @test (x ÷ 2).value == x.value / 2
        @test (w ÷ 2).value == w.value / 2
        @test_throws ErrorException x ÷ 0.2
        @test sqrt(x).value == sqrt(x.value)
        @test decorrelate(x).value == x.value
        @test float.(X * Y) == float.(X) * float.(Y)
        @test float.(X * v) == float.(X) * float.(v)
        @test norm(v).value == norm(float.(v))
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
                @test begin
                    z = 0
                    for t in 1:T
                        bit = pop!(op(w, 2))
                        z += pos(bit) - neg(bit)
                    end

                    z / T
                end ≈ op(w, 2).value atol = 0.01
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
                @test begin
                    z = 0
                    for t in 1:T
                        bit = pop!(op(x, w))
                        z += pos(bit) - neg(bit)
                    end

                    z / T
                end ≈ op(x, w).value atol = 0.01
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
        @testset "op = * (matrix, matrix)" begin
            @test begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(X * Y)
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(X * Y) atol = 0.05
            @test begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(Y * X)
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(Y * X) atol = 0.05
        end
        @testset "op = * (matrix, vector)" begin
            @test begin
                T = 50000
                Z = zeros(2)
                for t in 1:T
                    bit = pop!.(X * v)
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(X * v) atol = 0.05
            @test_broken begin
                T = 100000
                Z = zeros(1, 2)
                for t in 1:T
                    bit = pop!.(transpose(v) * X)
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(transpose(v) * X) atol = 0.05
        end
        @testset "op = norm" begin
            @test begin
                T = 50000
                z = 0
                for t in 1:T
                    bit = pop!(norm(v))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ norm(v).value atol = 0.01
        end
    end
end