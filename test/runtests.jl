using Test
using FileIO

@testset "VulkanExamples.jl" begin
    @testset "Headless" begin
        include("../examples/headless/headless.jl")
        dst = tempname() * ".png"
        main(
            joinpath(@__DIR__, "render.png"),
            Point2f[(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)],
            [
                RGBA{Float16}(0.0, 0.0, 1.0, 0.0),
                RGBA{Float16}(0.0, 1.0, 0.0, 0.05),
                RGBA{Float16}(1.0, 1.0, 1.0, 0.4),
                RGBA{Float16}(1.0, 0.0, 0.0, 1.0),
            ],
        )
        @test stat(dst).size > 1
    end
    @testset "Texture" begin
        include("../examples/texture/texture_2d.jl")
        dst = tempname() * ".png"
        main(
            joinpath(@__DIR__, "render.png"),
            Point2f[(-1., -1.), (1., -1.), (-1., 1.), (1., 1.)],
            joinpath(@__DIR__, "texture_2d.png"),
            width = 1024,
            height = 1024,
        )
        @test stat(dst).size > 1
    end
end
