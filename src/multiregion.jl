"""
    regional_price_index(name, regions, goods_by_region; price_var=:p,
        index_var=:P_HH, common_index_var=nothing, params)

Construct regional price indices from region-specific goods and calibrated
weights. When `common_index_var` is supplied, also construct a calibrated
weighted aggregate of the regional indices. Required parameters are
`weight[(good, region)]` and, for a common index, `common_weight[region]`.
`positive_lower` supplies a numerical lower bound for price variables.
"""
struct RegionalPriceIndexBlock <: JCGECore.AbstractBlock
    name::Symbol
    regions::Vector{Symbol}
    goods_by_region::Dict{Symbol,Vector{Symbol}}
    price_var::Symbol
    index_var::Symbol
    common_index_var::Union{Nothing,Symbol}
    params::NamedTuple
end

function regional_price_index(name::Symbol, regions::Vector{Symbol},
    goods_by_region::Dict{Symbol,Vector{Symbol}};
    price_var::Symbol = :p,
    index_var::Symbol = :P_HH,
    common_index_var::Union{Nothing,Symbol} = nothing,
    params::NamedTuple)
    return RegionalPriceIndexBlock(
        name,
        copy(regions),
        Dict(region => copy(goods_by_region[region]) for region in regions),
        price_var,
        index_var,
        common_index_var,
        params,
    )
end

"""
    regional_factor_availability(name, regions, factors_by_region,
        activities_by_region; factor_input=:F, factor_price=:pf,
        price_index=:P_HH, params)

Impose regional factor availability and fixed factor prices in real terms.
For each factor, total use across activities in its region cannot exceed its
calibrated endowment, while its nominal price equals the calibrated real price
times the regional price index. Required parameters are `endowment[factor]`,
`real_price[factor]`, and `positive_lower`.
"""
struct RegionalFactorAvailabilityBlock <: JCGECore.AbstractBlock
    name::Symbol
    regions::Vector{Symbol}
    factors_by_region::Dict{Symbol,Vector{Symbol}}
    activities_by_region::Dict{Symbol,Vector{Symbol}}
    factor_input::Symbol
    factor_price::Symbol
    price_index::Symbol
    params::NamedTuple
end

function regional_factor_availability(name::Symbol, regions::Vector{Symbol},
    factors_by_region::Dict{Symbol,Vector{Symbol}},
    activities_by_region::Dict{Symbol,Vector{Symbol}};
    factor_input::Symbol = :F,
    factor_price::Symbol = :pf,
    price_index::Symbol = :P_HH,
    params::NamedTuple)
    return RegionalFactorAvailabilityBlock(
        name,
        copy(regions),
        Dict(region => copy(factors_by_region[region]) for region in regions),
        Dict(region => copy(activities_by_region[region]) for region in regions),
        factor_input,
        factor_price,
        price_index,
        params,
    )
end

function _positive_lower(params::NamedTuple)
    hasproperty(params, :positive_lower) ||
        error("Multi-region blocks require params.positive_lower.")
    lower = Float64(getproperty(params, :positive_lower))
    lower > 0.0 || error("params.positive_lower must be strictly positive.")
    return lower
end

function _register_multiregion_equation!(ctx::JCGERuntime.KernelContext,
    block, tag::Symbol, idxs::Symbol...;
    info::Union{Nothing,String}=nothing,
    expr=nothing,
    index_names=nothing,
    constraint=nothing,
    objective_expr=nothing,
    objective_sense=nothing)
    payload = _build_payload(
        block,
        idxs,
        index_names,
        info,
        expr,
        constraint,
        nothing,
        objective_expr,
        objective_sense,
    )
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=payload)
    return nothing
end

function JCGECore.build!(block::RegionalPriceIndexBlock,
    ctx::JCGERuntime.KernelContext,
    spec::JCGECore.RunSpec)
    model = ctx.model
    lower = _positive_lower(block.params)

    for region in block.regions
        goods = get(block.goods_by_region, region, nothing)
        goods === nothing && error("Missing goods for region $(region).")
        isempty(goods) && error("Regional price index requires at least one good for $(region).")
        for good in goods
            ensure_var!(ctx, model, global_var(block.price_var, good); lower=lower)
        end
        ensure_var!(ctx, model, global_var(block.index_var, region); lower=lower)
        expr = EEq(
            EVar(block.index_var, Any[region]),
            EAdd([
                EMul([
                    EParam(:weight, Any[good, region]),
                    EVar(block.price_var, Any[good]),
                ])
                for good in goods
            ]),
        )
        _register_multiregion_equation!(ctx, block, :regional_price_index, region;
            info="regional price index equals the calibrated weighted price average",
            expr=expr,
            index_names=(:region,),
            constraint=nothing)
    end

    if block.common_index_var !== nothing
        ensure_var!(ctx, model, block.common_index_var; lower=lower)
        expr = EEq(
            EVar(block.common_index_var, Any[]),
            EAdd([
                EMul([
                    EParam(:common_weight, Any[region]),
                    EVar(block.index_var, Any[region]),
                ])
                for region in block.regions
            ]),
        )
        _register_multiregion_equation!(ctx, block, :common_price_index;
            info="common price index equals the calibrated weighted average of regional price indices",
            expr=expr,
            constraint=nothing)
    end

    return nothing
end

function JCGECore.build!(block::RegionalFactorAvailabilityBlock,
    ctx::JCGERuntime.KernelContext,
    spec::JCGECore.RunSpec)
    model = ctx.model
    lower = _positive_lower(block.params)

    for region in block.regions
        factors = get(block.factors_by_region, region, nothing)
        activities = get(block.activities_by_region, region, nothing)
        factors === nothing && error("Missing factors for region $(region).")
        activities === nothing && error("Missing activities for region $(region).")
        isempty(activities) && error("Regional factor availability requires activities for $(region).")
        ensure_var!(ctx, model, global_var(block.price_index, region); lower=lower)

        for factor in factors
            ensure_var!(ctx, model, global_var(block.factor_price, factor); lower=lower)
            for activity in activities
                ensure_var!(ctx, model, global_var(block.factor_input, factor, activity); lower=lower)
            end

            availability = ELe(
                EAdd([EVar(block.factor_input, Any[factor, activity]) for activity in activities]),
                EParam(:endowment, Any[factor]),
            )
            _register_multiregion_equation!(ctx, block, :factor_availability, factor, region;
                info="regional factor use cannot exceed the calibrated endowment",
                expr=availability,
                index_names=(:factor, :region),
                constraint=nothing)

            real_price = EEq(
                EVar(block.factor_price, Any[factor]),
                EMul([
                    EParam(:real_price, Any[factor]),
                    EVar(block.price_index, Any[region]),
                ]),
            )
            _register_multiregion_equation!(ctx, block, :fixed_real_factor_price, factor, region;
                info="regional factor price equals the calibrated real price times the regional price index",
                expr=real_price,
                index_names=(:factor, :region),
                constraint=nothing)
        end
    end

    return nothing
end

"""
    TradeRoute(id, product, origin, destination)

One bilateral flow in a multi-region trade system. `origin` and `destination`
are model regions, except that either endpoint may be `:ROW` to represent a
trade counterpart outside the modelled regions. `:ROW` is not itself a region
or a production system.
"""
struct TradeRoute
    id::Symbol
    product::Symbol
    origin::Symbol
    destination::Symbol
end

trade_route(id::Symbol, product::Symbol, origin::Symbol, destination::Symbol) =
    TradeRoute(id, product, origin, destination)

"""
    multiregion_trade(name, regions, routes, goods; kwargs..., params)

Construct linked multi-origin Armington demand and multi-destination CET
supply for a set of bilateral `TradeRoute`s. Each route has one quantity,
seller price, and delivered price, so supply allocation and demand sourcing
refer to the same flow.

`goods[(product, region)]` maps a product in each modelled region to the
corresponding commodity identifier. `:ROW` may appear only as an endpoint of
a route and is assigned exogenous route-specific prices through
`world_price[route]`.

Required parameters are `armington_scale[product, destination]`,
`armington_share[route]`, `armington_exponent[product, destination]`,
`cet_scale[product, origin]`, `cet_share[route]`,
`cet_exponent[product, origin]`, `output_tax[product, origin]`,
`delivery_wedge[route]`, `world_price[route]` for ROW routes, and
`positive_lower`. An exponent of zero is represented exactly by its
Cobb--Douglas limit; it is not approximated numerically.
"""
struct MultiRegionTradeBlock <: JCGECore.AbstractBlock
    name::Symbol
    regions::Vector{Symbol}
    routes::Vector{TradeRoute}
    goods::Dict{Tuple{Symbol,Symbol},Symbol}
    output_var::Symbol
    output_price_var::Symbol
    composite_var::Symbol
    composite_price_var::Symbol
    flow_var::Symbol
    seller_price_var::Symbol
    delivered_price_var::Symbol
    params::NamedTuple
end

function multiregion_trade(name::Symbol,
    regions::Vector{Symbol},
    routes::Vector{TradeRoute},
    goods::Dict{Tuple{Symbol,Symbol},Symbol};
    output_var::Symbol = :Z,
    output_price_var::Symbol = :pz,
    composite_var::Symbol = :Q,
    composite_price_var::Symbol = :pq,
    flow_var::Symbol = :T,
    seller_price_var::Symbol = :pS,
    delivered_price_var::Symbol = :pD,
    params::NamedTuple)
    return MultiRegionTradeBlock(
        name,
        copy(regions),
        copy(routes),
        copy(goods),
        output_var,
        output_price_var,
        composite_var,
        composite_price_var,
        flow_var,
        seller_price_var,
        delivered_price_var,
        params,
    )
end

"""
    regional_external_account(name, regions, routes; flow_var=:T,
        seller_price_var=:pS, foreign_saving_var=:FSAV, params=(;))

Record the ROW trade balance of each modelled region. A positive
`FSAV[region]` is the external financing required for that region's import
excess. The block does not create a ROW region; it only records transactions
on routes for which one endpoint is `:ROW`.
"""
struct RegionalExternalAccountBlock <: JCGECore.AbstractBlock
    name::Symbol
    regions::Vector{Symbol}
    routes::Vector{TradeRoute}
    flow_var::Symbol
    seller_price_var::Symbol
    foreign_saving_var::Symbol
    params::NamedTuple
end

function regional_external_account(name::Symbol,
    regions::Vector{Symbol},
    routes::Vector{TradeRoute};
    flow_var::Symbol = :T,
    seller_price_var::Symbol = :pS,
    foreign_saving_var::Symbol = :FSAV,
    params::NamedTuple = (;))
    return RegionalExternalAccountBlock(
        name,
        copy(regions),
        copy(routes),
        flow_var,
        seller_price_var,
        foreign_saving_var,
        params,
    )
end

function _trade_product_list(routes::Vector{TradeRoute})
    products = Symbol[]
    for route in routes
        route.product in products || push!(products, route.product)
    end
    return products
end

function _trade_groups(block::MultiRegionTradeBlock)
    isempty(block.regions) && error("Multi-region trade requires at least one modelled region.")
    isempty(block.routes) && error("Multi-region trade requires at least one route.")

    region_set = Set(block.regions)
    ids = Set{Symbol}()
    links = Set{Tuple{Symbol,Symbol,Symbol}}()
    supply = Dict{Tuple{Symbol,Symbol},Vector{TradeRoute}}()
    demand = Dict{Tuple{Symbol,Symbol},Vector{TradeRoute}}()

    for route in block.routes
        route.id in ids && error("Duplicate trade-route identifier $(route.id).")
        push!(ids, route.id)
        key = (route.product, route.origin, route.destination)
        key in links && error("Duplicate trade route $(key).")
        push!(links, key)

        route.origin == :ROW || route.origin in region_set ||
            error("Trade-route origin $(route.origin) is not a modelled region or :ROW.")
        route.destination == :ROW || route.destination in region_set ||
            error("Trade-route destination $(route.destination) is not a modelled region or :ROW.")
        route.origin == :ROW && route.destination == :ROW &&
            error("A trade route cannot run from :ROW to :ROW.")

        if route.origin != :ROW
            haskey(block.goods, (route.product, route.origin)) ||
                error("Missing commodity mapping for product $(route.product) in origin $(route.origin).")
            push!(get!(supply, (route.product, route.origin), TradeRoute[]), route)
        end
        if route.destination != :ROW
            haskey(block.goods, (route.product, route.destination)) ||
                error("Missing commodity mapping for product $(route.product) in destination $(route.destination).")
            push!(get!(demand, (route.product, route.destination), TradeRoute[]), route)
        end
    end

    for product in _trade_product_list(block.routes), region in block.regions
        haskey(block.goods, (product, region)) || continue
        haskey(supply, (product, region)) ||
            error("Product $(product) in $(region) has an output mapping but no destination route.")
        haskey(demand, (product, region)) ||
            error("Product $(product) in $(region) has a commodity mapping but no source route.")
    end
    return supply, demand
end

function _required_trade_param(params::NamedTuple, name::Symbol, idxs::Symbol...)
    hasproperty(params, name) || error("Multi-region trade requires params.$(name).")
    return JCGECore.getparam(params, name, idxs...)
end

function _positive_trade_param(params::NamedTuple, name::Symbol, idxs::Symbol...)
    value = _required_trade_param(params, name, idxs...)
    value > 0 || error("params.$(name)$(isempty(idxs) ? "" : "[$(join(idxs, ", "))]") must be positive.")
    return value
end

function _trade_exponent(params::NamedTuple, name::Symbol, product::Symbol, region::Symbol)
    exponent = _required_trade_param(params, name, product, region)
    exponent < 1 || error("params.$(name)[$(product), $(region)] must be less than one.")
    return exponent
end

function _ces_quantity_expr(scale_name::Symbol, share_name::Symbol,
    exponent_name::Symbol, quantity_var::Symbol, aggregate_var::Symbol,
    product::Symbol, region::Symbol, routes::Vector{TradeRoute})
    exponent = EParam(exponent_name, Any[product, region])
    aggregate = EVar(aggregate_var, Any[])
    route_ids = Symbol[route.id for route in routes]
    return EEq(
        aggregate,
        EMul([
            EParam(scale_name, Any[product, region]),
            EPow(
                EAdd([
                    EMul([
                        EParam(share_name, Any[route.id]),
                        EPow(EVar(quantity_var, Any[route.id]), exponent),
                    ])
                    for route in routes
                ]),
                EDiv(EConst(1.0), exponent),
            ),
        ]),
    )
end

function _cd_quantity_expr(scale_name::Symbol, share_name::Symbol,
    quantity_var::Symbol, aggregate_var::Symbol,
    product::Symbol, region::Symbol, routes::Vector{TradeRoute})
    route_ids = Symbol[route.id for route in routes]
    return EEq(
        EVar(aggregate_var, Any[]),
        EMul([
            EParam(scale_name, Any[product, region]),
            EProd(:route, route_ids,
                EPow(EVar(quantity_var, Any[EIndex(:route)]),
                    EParam(share_name, Any[EIndex(:route)]))),
        ]),
    )
end

function JCGECore.build!(block::MultiRegionTradeBlock,
    ctx::JCGERuntime.KernelContext,
    spec::JCGECore.RunSpec)
    model = ctx.model
    lower = _positive_lower(block.params)
    supply, demand = _trade_groups(block)

    for route in block.routes
        _positive_trade_param(block.params, :delivery_wedge, route.id)
        ensure_var!(ctx, model, global_var(block.flow_var, route.id); lower=lower)
        ensure_var!(ctx, model, global_var(block.seller_price_var, route.id); lower=lower)
        ensure_var!(ctx, model, global_var(block.delivered_price_var, route.id); lower=lower)

        delivery_price = EEq(
            EVar(block.delivered_price_var, Any[route.id]),
            EMul([
                EParam(:delivery_wedge, Any[route.id]),
                EVar(block.seller_price_var, Any[route.id]),
            ]),
        )
        _register_multiregion_equation!(ctx, block, :trade_delivery_price, route.id;
            info="route delivered price equals its calibrated delivery wedge times its seller price",
            expr=delivery_price,
            index_names=(:route,),
            constraint=nothing)

        if route.origin == :ROW || route.destination == :ROW
            _positive_trade_param(block.params, :world_price, route.id)
            world_price = EEq(
                EVar(block.seller_price_var, Any[route.id]),
                EParam(:world_price, Any[route.id]),
            )
            _register_multiregion_equation!(ctx, block, :row_trade_price, route.id;
                info="ROW route seller price is exogenous",
                expr=world_price,
                index_names=(:route,),
                constraint=nothing)
        end
    end

    for ((product, origin), routes) in supply
        good = block.goods[(product, origin)]
        exponent = _trade_exponent(block.params, :cet_exponent, product, origin)
        _positive_trade_param(block.params, :cet_scale, product, origin)
        output_tax = _required_trade_param(block.params, :output_tax, product, origin)
        1 + output_tax > 0 ||
            error("params.output_tax[$(product), $(origin)] must be greater than -1.")
        for route in routes
            _positive_trade_param(block.params, :cet_share, route.id)
        end

        ensure_var!(ctx, model, global_var(block.output_var, good); lower=lower)
        ensure_var!(ctx, model, global_var(block.output_price_var, good); lower=lower)
        if iszero(exponent)
            transform = _cd_quantity_expr(
                :cet_scale, :cet_share, block.flow_var, block.output_var,
                product, origin, routes,
            )
            info = "output is the exact Cobb-Douglas limit of a multi-destination CET transformation"
            tag = :cet_cobb_douglas
        else
            transform = _ces_quantity_expr(
                :cet_scale, :cet_share, :cet_exponent, block.flow_var, block.output_var,
                product, origin, routes,
            )
            info = "output is a multi-destination CET transformation of bilateral sales"
            tag = :cet_quantity
        end
        transform = EEq(EVar(block.output_var, Any[good]), transform.rhs)
        _register_multiregion_equation!(ctx, block, tag, product, origin;
            info=info,
            expr=transform,
            index_names=(:product, :origin),
            constraint=nothing)

        for route in routes
            allocation = if iszero(exponent)
                EEq(
                    EVar(block.flow_var, Any[route.id]),
                    EMul([
                        EParam(:cet_share, Any[route.id]),
                        EAdd([EConst(1.0), EParam(:output_tax, Any[product, origin])]),
                        EDiv(
                            EVar(block.output_price_var, Any[good]),
                            EVar(block.seller_price_var, Any[route.id]),
                        ),
                        EVar(block.output_var, Any[good]),
                    ]),
                )
            else
                EEq(
                    EVar(block.flow_var, Any[route.id]),
                    EMul([
                        EPow(
                            EDiv(
                                EMul([
                                    EPow(EParam(:cet_scale, Any[product, origin]),
                                        EParam(:cet_exponent, Any[product, origin])),
                                    EParam(:cet_share, Any[route.id]),
                                    EAdd([EConst(1.0), EParam(:output_tax, Any[product, origin])]),
                                    EVar(block.output_price_var, Any[good]),
                                ]),
                                EVar(block.seller_price_var, Any[route.id]),
                            ),
                            EDiv(
                                EConst(1.0),
                                EAdd([EConst(1.0), ENeg(EParam(:cet_exponent, Any[product, origin]))]),
                            ),
                        ),
                        EVar(block.output_var, Any[good]),
                    ]),
                )
            end
            _register_multiregion_equation!(ctx, block,
                iszero(exponent) ? :cet_allocation_cobb_douglas : :cet_allocation,
                route.id;
                info="bilateral sales follow the CET first-order allocation condition",
                expr=allocation,
                index_names=(:route,),
                constraint=nothing)
        end
    end

    for ((product, destination), routes) in demand
        good = block.goods[(product, destination)]
        exponent = _trade_exponent(block.params, :armington_exponent, product, destination)
        _positive_trade_param(block.params, :armington_scale, product, destination)
        for route in routes
            _positive_trade_param(block.params, :armington_share, route.id)
        end

        ensure_var!(ctx, model, global_var(block.composite_var, good); lower=lower)
        ensure_var!(ctx, model, global_var(block.composite_price_var, good); lower=lower)
        if iszero(exponent)
            composite = _cd_quantity_expr(
                :armington_scale, :armington_share, block.flow_var, block.composite_var,
                product, destination, routes,
            )
            info = "composite demand is the exact Cobb-Douglas limit of a multi-origin Armington nest"
            tag = :armington_cobb_douglas
        else
            composite = _ces_quantity_expr(
                :armington_scale, :armington_share, :armington_exponent,
                block.flow_var, block.composite_var, product, destination, routes,
            )
            info = "composite demand is a multi-origin Armington aggregation of bilateral purchases"
            tag = :armington_quantity
        end
        composite = EEq(EVar(block.composite_var, Any[good]), composite.rhs)
        _register_multiregion_equation!(ctx, block, tag, product, destination;
            info=info,
            expr=composite,
            index_names=(:product, :destination),
            constraint=nothing)

        for route in routes
            sourcing = if iszero(exponent)
                EEq(
                    EVar(block.flow_var, Any[route.id]),
                    EMul([
                        EParam(:armington_share, Any[route.id]),
                        EDiv(
                            EVar(block.composite_price_var, Any[good]),
                            EVar(block.delivered_price_var, Any[route.id]),
                        ),
                        EVar(block.composite_var, Any[good]),
                    ]),
                )
            else
                EEq(
                    EVar(block.flow_var, Any[route.id]),
                    EMul([
                        EPow(
                            EDiv(
                                EMul([
                                    EPow(EParam(:armington_scale, Any[product, destination]),
                                        EParam(:armington_exponent, Any[product, destination])),
                                    EParam(:armington_share, Any[route.id]),
                                    EVar(block.composite_price_var, Any[good]),
                                ]),
                                EVar(block.delivered_price_var, Any[route.id]),
                            ),
                            EDiv(
                                EConst(1.0),
                                EAdd([EConst(1.0), ENeg(EParam(:armington_exponent, Any[product, destination]))]),
                            ),
                        ),
                        EVar(block.composite_var, Any[good]),
                    ]),
                )
            end
            _register_multiregion_equation!(ctx, block,
                iszero(exponent) ? :armington_sourcing_cobb_douglas : :armington_sourcing,
                route.id;
                info="bilateral purchases follow the Armington first-order sourcing condition",
                expr=sourcing,
                index_names=(:route,),
                constraint=nothing)
        end
    end

    return nothing
end

function JCGECore.build!(block::RegionalExternalAccountBlock,
    ctx::JCGERuntime.KernelContext,
    spec::JCGECore.RunSpec)
    model = ctx.model
    region_set = Set(block.regions)
    for route in block.routes
        route.origin == :ROW || route.origin in region_set ||
            error("External-account route origin $(route.origin) is not a modelled region or :ROW.")
        route.destination == :ROW || route.destination in region_set ||
            error("External-account route destination $(route.destination) is not a modelled region or :ROW.")
    end

    for region in block.regions
        imports = [route for route in block.routes if route.origin == :ROW && route.destination == region]
        exports = [route for route in block.routes if route.origin == region && route.destination == :ROW]
        ensure_var!(ctx, model, global_var(block.foreign_saving_var, region); lower=-Inf)
        for route in vcat(imports, exports)
            ensure_var!(ctx, model, global_var(block.flow_var, route.id); lower=0.0)
            ensure_var!(ctx, model, global_var(block.seller_price_var, route.id); lower=0.0)
        end
        import_value = EAdd([
            EMul([
                EVar(block.seller_price_var, Any[route.id]),
                EVar(block.flow_var, Any[route.id]),
            ])
            for route in imports
        ])
        export_value = EAdd([
            EMul([
                EVar(block.seller_price_var, Any[route.id]),
                EVar(block.flow_var, Any[route.id]),
            ])
            for route in exports
        ])
        balance = EEq(
            EVar(block.foreign_saving_var, Any[region]),
            EAdd([import_value, ENeg(export_value)]),
        )
        _register_multiregion_equation!(ctx, block, :regional_external_balance, region;
            info="positive foreign saving finances the region's excess of ROW imports over ROW exports",
            expr=balance,
            index_names=(:region,),
            constraint=nothing)
    end
    return nothing
end

"""
    regional_investment_pool(name, regions, goods_by_region; kwargs..., params)

Close regional saving and investment through one pool shared by the modelled
regions. `goods_by_region` identifies the composite investment goods in each
region. The block values those quantities at their composite prices, records a
signed pool transfer for every region, and requires those transfers to sum to
zero.

The regional saving, government saving, and foreign-saving variables are
model-defined inputs. This block does not prescribe their behavioural closure.
Required parameter: `positive_lower`.
"""
struct RegionalInvestmentPoolBlock <: JCGECore.AbstractBlock
    name::Symbol
    regions::Vector{Symbol}
    goods_by_region::Dict{Symbol,Vector{Symbol}}
    private_saving_var::Symbol
    government_saving_var::Symbol
    foreign_saving_var::Symbol
    investment_quantity_var::Symbol
    composite_price_var::Symbol
    investment_spending_var::Symbol
    pool_transfer_var::Symbol
    params::NamedTuple
end

function regional_investment_pool(name::Symbol,
    regions::Vector{Symbol},
    goods_by_region::Dict{Symbol,Vector{Symbol}};
    private_saving_var::Symbol = :Sp,
    government_saving_var::Symbol = :Sg,
    foreign_saving_var::Symbol = :FSAV,
    investment_quantity_var::Symbol = :Xv,
    composite_price_var::Symbol = :pq,
    investment_spending_var::Symbol = :INV,
    pool_transfer_var::Symbol = :INV_POOL,
    params::NamedTuple)
    return RegionalInvestmentPoolBlock(
        name,
        copy(regions),
        Dict(region => copy(goods_by_region[region]) for region in regions),
        private_saving_var,
        government_saving_var,
        foreign_saving_var,
        investment_quantity_var,
        composite_price_var,
        investment_spending_var,
        pool_transfer_var,
        params,
    )
end

function JCGECore.build!(block::RegionalInvestmentPoolBlock,
    ctx::JCGERuntime.KernelContext,
    spec::JCGECore.RunSpec)
    model = ctx.model
    lower = _positive_lower(block.params)

    for region in block.regions
        goods = get(block.goods_by_region, region, nothing)
        goods === nothing && error("Missing investment goods for region $(region).")
        isempty(goods) && error("Regional investment pool requires at least one investment good for $(region).")
        ensure_var!(ctx, model, global_var(block.private_saving_var, region); lower=lower)
        ensure_var!(ctx, model, global_var(block.government_saving_var, region); lower=lower)
        ensure_var!(ctx, model, global_var(block.foreign_saving_var, region); lower=-Inf)
        ensure_var!(ctx, model, global_var(block.investment_spending_var, region); lower=lower)
        ensure_var!(ctx, model, global_var(block.pool_transfer_var, region); lower=-Inf)
        for good in goods
            ensure_var!(ctx, model, global_var(block.investment_quantity_var, good); lower=lower)
            ensure_var!(ctx, model, global_var(block.composite_price_var, good); lower=lower)
        end

        investment_spending = EEq(
            EVar(block.investment_spending_var, Any[region]),
            EAdd([
                EMul([
                    EVar(block.composite_price_var, Any[good]),
                    EVar(block.investment_quantity_var, Any[good]),
                ])
                for good in goods
            ]),
        )
        _register_multiregion_equation!(ctx, block, :regional_investment_spending, region;
            info="regional investment spending equals the value of its composite investment goods",
            expr=investment_spending,
            index_names=(:region,),
            constraint=nothing)

        funding = EEq(
            EVar(block.investment_spending_var, Any[region]),
            EAdd([
                EVar(block.private_saving_var, Any[region]),
                EVar(block.government_saving_var, Any[region]),
                EVar(block.foreign_saving_var, Any[region]),
                EVar(block.pool_transfer_var, Any[region]),
            ]),
        )
        _register_multiregion_equation!(ctx, block, :regional_investment_funding, region;
            info="regional investment equals private saving, government saving, foreign saving, and the pool transfer",
            expr=funding,
            index_names=(:region,),
            constraint=nothing)
    end

    pool_clearing = EEq(
        EAdd([EVar(block.pool_transfer_var, Any[region]) for region in block.regions]),
        EConst(0.0),
    )
    _register_multiregion_equation!(ctx, block, :investment_pool_clearing;
        info="regional investment-pool transfers sum to zero",
        expr=pool_clearing,
        constraint=nothing)
    return nothing
end
