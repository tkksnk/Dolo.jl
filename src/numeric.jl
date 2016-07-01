# ------------------- #
# Numeric model types #
# ------------------- #
immutable Options
    distribution
    grid
    other::Dict{Symbol,Any}  # TODO: shouldn't need. Just keeps stuff around
end

Options(;grid=nothing, distribution=nothing, other=Dict{Symbol,Any}()) =
    Options(grid, distribution, other)


function Options(sm::AbstractSymbolicModel, calib::ModelCalibration)
    # numericize options
    _options = eval_with(calib, deepcopy(sm.options))

    _opts = Dict{Symbol,Any}()
    other = Dict{Symbol,Any}()

    # now construct Options object
    for k in keys(_options)
        data = pop!(_options, k)
        if k == :grid
            if data[:kind] == :Cartesian
                _opts[:grid] = Cartesian(data)
            else
                m = "don't know how to handle grid of type $(data[:kind])"
                error(m)
            end
        elseif k == :distribution
            if data[:kind] == :Normal
                n = length(calib[:shocks])
                sigma = reshape(vcat(data[:sigma]...), n, n)
                _opts[k] = Normal(_to_Float64(sigma))

            else
                m = "don't know how to handle distribution of type $(data[:kind])"
                error(m)
            end
        else
            other[k] = data
        end
    end

    Options(;_opts..., other=other)
end

immutable Cartesian
    a::Vector{Float64}
    b::Vector{Float64}
    orders::Vector{Int}
end

function Cartesian(stuff::Associative)
    kind = get(stuff, :kind, nothing)
    if kind != :Cartesian
        error("Can't build Cartesian from dict with kind $(kind)")
    end

    Cartesian(stuff[:a], stuff[:b], stuff[:orders])
end

immutable Normal
    sigma::Matrix{Float64}
end

immutable DTCSCCModel{ID} <: ANM{ID,:dtcscc}
    symbolic::ASM
    calibration::ModelCalibration
    options::Options
    model_type::Symbol
    name::UTF8String
    filename::UTF8String
end

immutable DTMSCCModel{ID} <: ANM{ID,:dtmscc}
    symbolic::ASM
    calibration::ModelCalibration
    options::Options
    model_type::Symbol
    name::UTF8String
    filename::UTF8String
end

_numeric_mod_type{ID}(::ASM{ID,:dtcscc}) = DTCSCCModel{ID}
_numeric_mod_type{ID}(::ASM{ID,:dtmscc}) = DTMSCCModel{ID}

for TM in (:DTCSCCModel, :DTMSCCModel)
    @eval begin
        Base.convert(::Type{SymbolicModel}, m::$(TM)) = m.symbolic

        # model type constructor
        function ($TM){ID}(sm::SymbolicModel{ID}; print_code::Bool=false)
            # compile all equations
            for eqn in keys(sm.equations)
                eval(Dolo, compile_equation(sm, eqn; print_code=print_code))
            end

            # get numerical calibration and options
            calib = ModelCalibration(sm)
            options = Options(sm, calib)


            $(TM){ID}(sm, calib, options, sm.model_type,
                      sm.name, sm.filename)
        end
    end
end

# ------------- #
# Other methods #
# ------------- #

filename(m::AbstractModel) = m.filename
name(m::AbstractModel) = m.name
