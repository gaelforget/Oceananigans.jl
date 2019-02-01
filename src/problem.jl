struct Problem
    c::PlanetaryConstants
    eos::EquationOfStateParameters
    g::Grid
    U::VelocityFields
    tr::TracerFields
    pr::PressureFields
    G::SourceTerms
    Gp::SourceTerms
    F::ForcingFields
    stmp::StepperTemporaryFields
    otmp::OperatorTemporaryFields
    # ssp::SpectralSolverParameters
    ssp
end

function Problem(N, L, arch=:cpu, FloatType=Float64)
    @assert arch == :cpu || arch == :gpu "arch must be :cpu or :gpu"

    c = EarthConstants()
    eos = LinearEquationOfState()

    g = RegularCartesianGrid(N, L, arch; FloatType=Float64)

    U  = VelocityFields(g)
    tr = TracerFields(g)
    pr = PressureFields(g)
    G  = SourceTerms(g)
    Gp = SourceTerms(g)
    F  = ForcingFields(g)
    stmp = StepperTemporaryFields(g)
    otmp = OperatorTemporaryFields(g)

    if arch == :cpu
        stmp.fCC1.data .= rand(eltype(g), g.Nx, g.Ny, g.Nz)
        ssp = SpectralSolverParameters(g, stmp.fCC1, FFTW.PATIENT; verbose=true)
    elseif arch == :gpu
        ssp = nothing
    end

    U.u.data  .= 0
    U.v.data  .= 0
    U.w.data  .= 0
    tr.S.data .= 35
    tr.T.data .= 283

    pHY_profile = [-eos.ρ₀*c.g*h for h in g.zC]
    if arch == :cpu
        pr.pHY.data .= repeat(reshape(pHY_profile, 1, 1, g.Nz), g.Nx, g.Ny, 1)
    elseif arch == :gpu
        pr.pHY.data .= cu(repeat(reshape(pHY_profile, 1, 1, g.Nz), g.Nx, g.Ny, 1))
    end

    ρ!(eos, g, tr)
    Problem(c, eos, g, U, tr, pr, G, Gp, F, stmp, otmp, ssp)
end