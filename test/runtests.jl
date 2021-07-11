using Test
using FileIO

@testset "VulkanExamples.jl" begin
    examples_dir = joinpath(dirname(@__DIR__), "examples")
    @testset "Headless" begin
        include(joinpath(examples_dir, "headless", "headless.jl"))
        dst = joinpath(examples_dir, "headless", tempname() * ".png")
        try
            main(
                dst,
                Point2f[(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)],
                [
                    RGBA{Float16}(0.0, 0.0, 1.0, 0.0),
                    RGBA{Float16}(0.0, 1.0, 0.0, 0.05),
                    RGBA{Float16}(1.0, 1.0, 1.0, 0.4),
                    RGBA{Float16}(1.0, 0.0, 0.0, 1.0),
                ],
            )
            @test stat(dst).size > 1
        finally
            ispath(dst) && rm(dst)
        end
    end
    @testset "Texture" begin
        include(joinpath(examples_dir, "texture", "texture_2d.jl"))
        dst = joinpath(examples_dir, "texture", tempname() * ".png")
        try
            main(
                dst,
                Point2f[(-1., -1.), (1., -1.), (-1., 1.), (1., 1.)],
                joinpath(examples_dir, "texture", "texture_2d.png"),
                width = 1024,
                height = 1024,
            )
            @test stat(dst).size > 1
        finally
            ispath(dst) && rm(dst)
        end
    end
end
