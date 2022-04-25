@testset "SBitstream" begin
    x = SBitstream(0.5)
    y = SBitstream(0.1)
    w = SBitstream(-0.1)
    X = SBitstream.(0.75 * rand(2, 2))
    Y = SBitstream.(-0.75 * rand(2, 2))
    v = SBitstream.([0.5 * rand(), -0.5 * rand()])

    @testset "FP Values" begin
        @test x.value == 0.5 && y.value == 0.1
        @test float(x) == x.value
        @testset for op in (+, -, *)
            @test float(op(x, y)) == op(float(x), float(y))
            @test float(op(x, w)) == op(float(x), float(w))
        end
        @test float(y / x) == float(y) / float(x)
        @test_logs (:warn, "SBitstream can only be ∈ [-1, 1] (saturation occurring).") float(x / y) == 1
        @test float(x ÷ 2) == float(x) / 2
        @test float(w ÷ 2) == float(w) / 2
        @test_throws ErrorException x ÷ 0.2
        @test float(sqrt(x)) == sqrt(float(x))
        @test float(decorrelate(x)) == float(x)
        @test float.(X * Y) == float.(X) * float.(Y)
        @test float.(X * v) == float.(X) * float.(v)
        @test float(norm(v)) == norm(float.(v))
        @test float(max(x, y)) == max(float(x), float(y))
    end

    @testset "Promotion" begin
        @test (x + 0.1) isa SBitstream{Float64}
        @test float(x + 0.1) == 0.6
        @test (x + 1) isa SBitstream{Float64}
    end

    @testset "Sample Generation" begin
        xbits = generate(x, 100000)
        @test mean(map(xbit -> pos(xbit) - neg(xbit), xbits)) ≈ x.value rtol = 0.1
    end

    @testset "Bit-Level Simulation" begin
        T = 50000
        @testset for op in (+, -, *, max)
            sim = simulatable(op, x, y)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(op, x, y))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(op(x, y)) rtol = 0.1
            sim = simulatable(op, y, x)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(op, y, x))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(op(y, x)) rtol = 0.1
            sim = simulatable(op, x, w)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(op, x, w))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(op(x, w)) rtol = 0.1
        end
        @testset "op = ÷" begin
            sim = simulatable(÷, x, 2)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(÷, x, 2))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(x ÷ 2) rtol = 0.1
            sim = simulatable(÷, w, 2)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(÷, w, 2))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(w ÷ 2) rtol = 0.1
        end
        @testset "op = /" begin
            sim = simulatable(/, y, x)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(/, y, x))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(y / x) rtol = 0.1
        end
        @testset for op in (sqrt, decorrelate)
            sim = simulatable(op, x)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(op, x))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(op(x)) rtol = 0.1
        end
        @testset "op = max(x, y, z)" begin
            sim = simulatable(max, x, y, w)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(max, x, y, w))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(max(x, y, w)) rtol = 0.1
        end
        @testset "op = average(x, y, z)" begin
            sim = simulatable(BitSAD.average, x, y, w)
            @test begin
                z = 0
                for t in 1:T
                    bit = pop!(sim(BitSAD.average, x, y, w))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(BitSAD.average(x, y, w)) rtol = 0.1
        end
        @testset "op = * (matrix, scalar)" begin
            sim = simulatable(*, X, y)
            @test_broken begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(sim(*, X, y))
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(X * y) rtol = 0.2
            sim = simulatable(*, y, X)
            @test_broken begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(sim(*, y, X))
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(y * X) rtol = 0.2
        end
        @testset "op = * (matrix, matrix)" begin
            sim = simulatable(*, X, Y)
            @test begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(sim(*, X, Y))
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(X * Y) rtol = 0.1
            sim = simulatable(*, Y, X)
            @test begin
                Z = zeros(2, 2)
                for t in 1:T
                    bit = pop!.(sim(*, Y, X))
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(Y * X) rtol = 0.1
        end
        @testset "op = * (matrix, vector)" begin
            sim = simulatable(*, X, v)
            @test begin
                T = 100000
                Z = zeros(2)
                for t in 1:T
                    bit = pop!.(sim(*, X, v))
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(X * v) rtol = 0.1
            sim = simulatable(*, transpose(v), X)
            @test begin
                T = 100000
                Z = zeros(1, 2)
                for t in 1:T
                    bit = pop!.(sim(*, transpose(v), X))
                    Z .+= pos.(bit) .- neg.(bit)
                end

                Z ./ T
            end ≈ float.(transpose(v) * X) rtol = 0.15
        end
        @testset "op = norm" begin
            sim = simulatable(norm, v)
            @test begin
                T = 100000
                z = 0
                for t in 1:T
                    bit = pop!(sim(norm, v))
                    z += pos(bit) - neg(bit)
                end

                z / T
            end ≈ float(norm(v)) rtol = 0.1
        end
    end
end
