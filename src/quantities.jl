"""
Generic auxiliary-quantity blocks.

These blocks introduce no domain vocabulary and no unit assumptions. They
provide a small algebra for quantities that must participate in an equilibrium
model: links to economic variables, fixed-coefficient transformations,
conservation identities, and capacity constraints. Numerical values remain in
named parameter sets; the block structures contain only identifiers and
mappings.
"""

"""
    QuantityLinkBlock

Define one auxiliary quantity per identifier as a coefficient times an
existing model variable. `driver_by_quantity` maps each quantity identifier to
the fully qualified symbol of that existing variable. Required parameter:
`coefficient[quantity]`.
"""
struct QuantityLinkBlock <: JCGECore.AbstractBlock
    name::Symbol
    quantities::Vector{Symbol}
    driver_by_quantity::Dict{Symbol,Symbol}
    quantity_var::Symbol
    lower::Union{Nothing,Float64}
    params::NamedTuple
end

"""
    QuantityTransformationBlock

Define output quantities as linear transformations of input quantities.
`inputs_by_output` records the structural input mapping, while the required
parameter `coefficient[(output, input)]` supplies every numerical factor.
"""
struct QuantityTransformationBlock <: JCGECore.AbstractBlock
    name::Symbol
    outputs::Vector{Symbol}
    inputs_by_output::Dict{Symbol,Vector{Symbol}}
    output_var::Symbol
    input_var::Symbol
    lower::Union{Nothing,Float64}
    params::NamedTuple
end

"""
    QuantityBalanceBlock

Impose one signed identity per balance identifier. `quantities_by_balance`
lists the participating quantities; the required parameter
`coefficient[(balance, quantity)]` supplies their signed coefficients.
"""
struct QuantityBalanceBlock <: JCGECore.AbstractBlock
    name::Symbol
    balances::Vector{Symbol}
    quantities_by_balance::Dict{Symbol,Vector{Symbol}}
    quantity_var::Symbol
    params::NamedTuple
end

"""
    QuantityCapacityBlock

Constrain each existing auxiliary quantity by `quantity <= capacity[quantity]`.
The required `capacity` parameter is keyed by quantity identifier.
"""
struct QuantityCapacityBlock <: JCGECore.AbstractBlock
    name::Symbol
    quantities::Vector{Symbol}
    quantity_var::Symbol
    params::NamedTuple
end

function _quantity_identifiers(ids, label::AbstractString)
    values = Symbol.(collect(ids))
    isempty(values) && error("$(label) requires at least one identifier.")
    length(unique(values)) == length(values) || error("$(label) identifiers must be unique.")
    return values
end

function _quantity_lower(lower)
    lower === nothing && return nothing
    value = Float64(lower)
    isfinite(value) || error("Auxiliary-quantity lower bounds must be finite when supplied.")
    return value
end

function _copy_quantity_mapping(ids::Vector{Symbol}, mapping, label::AbstractString)
    copied = Dict{Symbol,Vector{Symbol}}()
    for id in ids
        entries = get(mapping, id, nothing)
        entries === nothing && error("$(label) is missing entries for $(id).")
        values = Symbol.(collect(entries))
        isempty(values) && error("$(label) entries for $(id) must not be empty.")
        length(unique(values)) == length(values) ||
            error("$(label) entries for $(id) must be unique.")
        copied[id] = values
    end
    extras = setdiff(Set(Symbol.(collect(keys(mapping)))), Set(ids))
    isempty(extras) || error("$(label) contains identifiers not declared by the block: $(join(string.(sort!(collect(extras))), ", ")).")
    return copied
end

function _ensure_quantity_variable!(ctx::JCGERuntime.KernelContext, model,
    name::Symbol, lower::Union{Nothing,Float64})
    haskey(ctx.variables, name) && return ctx.variables[name]
    if model isa JuMP.Model
        variable = lower === nothing ?
            @variable(model, base_name=string(name)) :
            @variable(model, lower_bound=lower, base_name=string(name))
    else
        variable = (name=name)
    end
    JCGERuntime.register_variable!(ctx, name, variable)
    return variable
end

function _require_quantity_variable!(ctx::JCGERuntime.KernelContext,
    variable::Symbol, quantity::Symbol, role::AbstractString)
    name = global_var(variable, quantity)
    haskey(ctx.variables, name) || error(
        "$(role) requires auxiliary variable $(name) to be defined by an earlier block.")
    return nothing
end

function _require_driver_variable!(ctx::JCGERuntime.KernelContext,
    driver::Symbol)
    haskey(ctx.variables, driver) || error(
        "QuantityLinkBlock requires mapped driver variable $(driver) to be defined by an earlier block.")
    return nothing
end

function _quantity_parameter(params::NamedTuple, name::Symbol, ids::Symbol...)
    value = JCGECore.getparam(params, name, ids...)
    value isa Real || error("Auxiliary-quantity parameter $(name) must be numeric.")
    isfinite(Float64(value)) || error("Auxiliary-quantity parameter $(name) must be finite.")
    return value
end

function _register_quantity_equation!(ctx::JCGERuntime.KernelContext, block,
    tag::Symbol, idxs::Symbol...; info::String, expr,
    index_names::Union{Nothing,Tuple}=nothing)
    payload = _build_payload(block, idxs, index_names, info, expr, nothing,
        nothing, nothing, nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=payload)
    return nothing
end

"""
    quantity_link(name, quantities, driver_by_quantity;
        quantity_var=:q, lower=0.0, params)

Create an auxiliary quantity for each identifier in `quantities`. The mapping
values must be fully qualified variable names already supplied by another
block, for example `:Z_activity_a`.
"""
function quantity_link(name::Symbol, quantities,
    driver_by_quantity::AbstractDict;
    quantity_var::Symbol=:q,
    lower::Union{Nothing,Real}=0.0,
    params::NamedTuple)
    ids = _quantity_identifiers(quantities, "QuantityLinkBlock")
    drivers = Dict{Symbol,Symbol}()
    for id in ids
        driver = get(driver_by_quantity, id, nothing)
        driver === nothing && error("QuantityLinkBlock is missing a driver for $(id).")
        drivers[id] = Symbol(driver)
    end
    extras = setdiff(Set(Symbol.(collect(keys(driver_by_quantity)))), Set(ids))
    isempty(extras) || error("QuantityLinkBlock contains drivers for undeclared quantities: $(join(string.(sort!(collect(extras))), ", ")).")
    hasproperty(params, :coefficient) || error("QuantityLinkBlock requires params.coefficient.")
    return QuantityLinkBlock(name, ids, drivers, quantity_var,
        _quantity_lower(lower), params)
end

"""
    quantity_transformation(name, outputs, inputs_by_output;
        output_var=:q, input_var=:q, lower=0.0, params)

Create linear transformations from mapped input quantities to output
quantities. Every listed pair requires `params.coefficient[(output, input)]`.
"""
function quantity_transformation(name::Symbol, outputs,
    inputs_by_output::AbstractDict;
    output_var::Symbol=:q,
    input_var::Symbol=:q,
    lower::Union{Nothing,Real}=0.0,
    params::NamedTuple)
    ids = _quantity_identifiers(outputs, "QuantityTransformationBlock")
    hasproperty(params, :coefficient) ||
        error("QuantityTransformationBlock requires params.coefficient.")
    return QuantityTransformationBlock(name, ids,
        _copy_quantity_mapping(ids, inputs_by_output, "QuantityTransformationBlock"),
        output_var, input_var, _quantity_lower(lower), params)
end

"""
    quantity_balance(name, balances, quantities_by_balance;
        quantity_var=:q, params)

Create signed identities over mapped auxiliary quantities. Every listed pair
requires `params.coefficient[(balance, quantity)]`.
"""
function quantity_balance(name::Symbol, balances,
    quantities_by_balance::AbstractDict;
    quantity_var::Symbol=:q,
    params::NamedTuple)
    ids = _quantity_identifiers(balances, "QuantityBalanceBlock")
    hasproperty(params, :coefficient) || error("QuantityBalanceBlock requires params.coefficient.")
    return QuantityBalanceBlock(name, ids,
        _copy_quantity_mapping(ids, quantities_by_balance, "QuantityBalanceBlock"),
        quantity_var, params)
end

"""
    quantity_capacity(name, quantities; quantity_var=:q, params)

Create upper-capacity constraints for already-defined auxiliary quantities.
Each identifier requires `params.capacity[quantity]`.
"""
function quantity_capacity(name::Symbol, quantities;
    quantity_var::Symbol=:q,
    params::NamedTuple)
    ids = _quantity_identifiers(quantities, "QuantityCapacityBlock")
    hasproperty(params, :capacity) || error("QuantityCapacityBlock requires params.capacity.")
    return QuantityCapacityBlock(name, ids, quantity_var, params)
end

function JCGECore.build!(block::QuantityLinkBlock,
    ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    model = ctx.model
    for quantity in block.quantities
        _quantity_parameter(block.params, :coefficient, quantity)
        _require_driver_variable!(ctx, block.driver_by_quantity[quantity])
        _ensure_quantity_variable!(ctx, model,
            global_var(block.quantity_var, quantity), block.lower)
        expr = EEq(
            EVar(block.quantity_var, Any[EIndex(:quantity)]),
            EMul([
                EParam(:coefficient, Any[EIndex(:quantity)]),
                EVar(block.driver_by_quantity[quantity], Any[]),
            ]),
        )
        _register_quantity_equation!(ctx, block, :quantity_link, quantity;
            info="auxiliary quantity equals its coefficient times the mapped model driver",
            expr=expr, index_names=(:quantity,))
    end
    return nothing
end

function JCGECore.build!(block::QuantityTransformationBlock,
    ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    model = ctx.model
    for output in block.outputs
        inputs = block.inputs_by_output[output]
        for input in inputs
            _quantity_parameter(block.params, :coefficient, output, input)
            _require_quantity_variable!(ctx, block.input_var, input,
                "QuantityTransformationBlock")
        end
        _ensure_quantity_variable!(ctx, model,
            global_var(block.output_var, output), block.lower)
        expr = EEq(
            EVar(block.output_var, Any[EIndex(:output)]),
            EAdd([
                EMul([
                    EParam(:coefficient, Any[EIndex(:output), input]),
                    EVar(block.input_var, Any[input]),
                ])
                for input in inputs
            ]),
        )
        _register_quantity_equation!(ctx, block, :quantity_transformation, output;
            info="auxiliary output quantity equals the mapped coefficient-weighted input quantities",
            expr=expr, index_names=(:output,))
    end
    return nothing
end

function JCGECore.build!(block::QuantityBalanceBlock,
    ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    for balance in block.balances
        quantities = block.quantities_by_balance[balance]
        for quantity in quantities
            _quantity_parameter(block.params, :coefficient, balance, quantity)
            _require_quantity_variable!(ctx, block.quantity_var, quantity,
                "QuantityBalanceBlock")
        end
        expr = EEq(
            EAdd([
                EMul([
                    EParam(:coefficient, Any[EIndex(:balance), quantity]),
                    EVar(block.quantity_var, Any[quantity]),
                ])
                for quantity in quantities
            ]),
            EConst(0.0),
        )
        _register_quantity_equation!(ctx, block, :quantity_balance, balance;
            info="signed auxiliary-quantity balance equals zero",
            expr=expr, index_names=(:balance,))
    end
    return nothing
end

function JCGECore.build!(block::QuantityCapacityBlock,
    ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    for quantity in block.quantities
        _quantity_parameter(block.params, :capacity, quantity)
        _require_quantity_variable!(ctx, block.quantity_var, quantity,
            "QuantityCapacityBlock")
        expr = ELe(
            EVar(block.quantity_var, Any[EIndex(:quantity)]),
            EParam(:capacity, Any[EIndex(:quantity)]),
        )
        _register_quantity_equation!(ctx, block, :quantity_capacity, quantity;
            info="auxiliary quantity cannot exceed its declared capacity",
            expr=expr, index_names=(:quantity,))
    end
    return nothing
end
