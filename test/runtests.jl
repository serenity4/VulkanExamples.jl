using Test
using FileIO

@testset "VulkanExamples.jl" begin
    @testset "Headless" begin
        include("../examples/headless/headless.jl")
        dst = tempname() * ".png"
        main(dst)
        @test stat(dst).size > 1
    end
end
