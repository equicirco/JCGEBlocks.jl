module JCGEBlocks

using JCGECore
using JCGECore: EAdd, EConst, EDiv, EEq, EIndex, EMul, ENeg, EParam, EProd, EPow, ESum, EVar, ERaw
using JCGERuntime
using JuMP
import MathOptInterface as MOI

export DummyBlock
export ProductionBlock
export ProductionCDBlock
export ProductionCDLeontiefBlock
export ProductionCDLeontiefSectorPFBlock
export ProductionMultilaborCDBlock
export FactorSupplyBlock
export HouseholdDemandBlock
export HouseholdDemandCDBlock
export HouseholdDemandCDXpBlock
export HouseholdDemandCDHHBlock
export HouseholdDemandCDXpRegionalBlock
export HouseholdDemandIncomeBlock
export MarketClearingBlock
export GoodsMarketClearingBlock
export FactorMarketClearingBlock
export CompositeMarketClearingBlock
export LaborMarketClearingBlock
export PriceLinkBlock
export ExchangeRateLinkBlock
export ExchangeRateLinkRegionBlock
export PriceEqualityBlock
export NumeraireBlock
export GovernmentBlock
export GovernmentRegionalBlock
export GovernmentBudgetBalanceBlock
export PrivateSavingBlock
export PrivateSavingRegionalBlock
export PrivateSavingIncomeBlock
export InvestmentBlock
export InvestmentRegionalBlock
export ArmingtonCESBlock
export TransformationCETBlock
export MonopolyRentBlock
export ImportQuotaBlock
export MobileFactorMarketBlock
export CapitalStockReturnBlock
export CompositeInvestmentBlock
export InvestmentAllocationBlock
export CompositeConsumptionBlock
export PriceLevelBlock
export PriceIndexBlock
export ClosureBlock
export UtilityBlock
export UtilityCDBlock
export UtilityCDXpBlock
export UtilityCDHHBlock
export UtilityCDRegionalBlock
export ExternalBalanceBlock
export ExternalBalanceVarPriceBlock
export ForeignTradeBlock
export PriceAggregationBlock
export InternationalMarketBlock
export ActivityPriceIOBlock
export ActivityAnalysisBlock
export ConsumerEndowmentCDBlock
export CommodityMarketClearingBlock
export CapitalPriceCompositionBlock
export TradePriceLinkBlock
export AbsorptionSalesBlock
export ArmingtonMXxdBlock
export CETXXDEBlock
export ExportDemandBlock
export NontradedSupplyBlock
export HouseholdShareDemandBlock
export HouseholdShareDemandHHBlock
export HouseholdIncomeLaborCapitalBlock
export HouseholdTaxRevenueBlock
export HouseholdIncomeSumBlock
export GovernmentShareDemandBlock
export InventoryDemandBlock
export GovernmentFinanceBlock
export GovernmentRevenueBlock
export ImportPremiumIncomeBlock
export GDPIncomeBlock
export SavingsInvestmentBlock
export FinalDemandClearingBlock
export ConsumptionObjectiveBlock
export ExternalBalanceRemitBlock
export InitialValuesBlock
export apply_start
export rerun!
export production
export production_sector_pf
export production_multilabor_cd

function mcp_enabled(params)
    return hasproperty(params, :mcp) && params.mcp === true
end

function mcp_constraint(model::JuMP.Model, expr, var)
    return @constraint(model, expr ⟂ var)
end
export factor_supply
export household_demand
export household_demand_regional
export household_demand_income
export household_share_demand_hh
export household_income_labor_capital
export household_tax_revenue
export household_income_sum
export market_clearing
export goods_market_clearing
export factor_market_clearing
export composite_market_clearing
export labor_market_clearing
export price_link
export exchange_rate_link
export exchange_rate_link_region
export price_equality
export numeraire
export government
export government_regional
export government_budget_balance
export government_revenue
export private_saving
export private_saving_regional
export private_saving_income
export investment
export investment_regional
export armington
export transformation
export monopoly_rent
export import_quota
export mobile_factor_market
export capital_stock_return
export composite_investment
export investment_allocation
export composite_consumption
export price_level
export price_index
export closure
export utility
export utility_regional
export external_balance
export external_balance_var_price
export external_balance_remit
export foreign_trade
export price_aggregation
export international_market
export activity_price_io
export capital_price_composition
export trade_price_link
export import_premium_income
export absorption_sales
export armington_m_xxd
export cet_xxd_e
export export_demand
export nontraded_supply
export household_share_demand
export government_share_demand
export inventory_demand
export government_finance
export gdp_income
export savings_investment
export final_demand_clearing
export consumption_objective
export initial_values
export activity_analysis
export consumer_endowment_cd
export commodity_market_clearing

"""
Minimal example block used to validate end-to-end wiring.

Registers a placeholder variable and a dummy equation without solving.
"""
struct DummyBlock <: JCGECore.AbstractBlock
    name::Symbol
end

function JCGECore.build!(block::DummyBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    JCGERuntime.register_variable!(ctx, Symbol(block.name, :_x), 1.0)
    JCGERuntime.register_equation!(ctx; tag=:dummy_eq, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="x==1 (placeholder)", expr=ERaw("x==1 (placeholder)"), constraint=nothing))
    return nothing
end

"""
    production(name, activities, factors, commodities; form=:cd, params)

General production block with per-activity functional forms.

Inputs:
- `activities`, `factors`, `commodities`: sets to use.
- `form`: Symbol (applied to all activities) or Dict of activity=>form.

Typical parameters (by form):
- Cobb-Douglas: `beta[h,i]`, `b[i]`, `ax[j,i]`, `ay[i]`
- Leontief nests: see `ProductionCDLeontiefBlock` for required coefficients.

Variables (global names):
- Output/composite: `Y[i]`, `Z[i]`
- Factor inputs: `F[h,i]`
- Intermediate inputs: `X[j,i]`
- Prices: `py[i]`, `pz[i]`, `pq[j]`

Equations (tags):
- `eqpy`, `eqF`, `eqX`, `eqY`, `eqpzs`

MCP:
- If `params.mcp=true`, complementarity variables are attached to each equation.
"""
production(name::Symbol, activities::Vector{Symbol}, factors::Vector{Symbol}, commodities::Vector{Symbol};
    form::Union{Symbol,Dict{Symbol,Symbol}}=:cd, params::NamedTuple) =
    ProductionBlock(
        name,
        activities,
        factors,
        commodities,
        form isa Symbol ? Dict(a => form for a in activities) : form,
        params,
    )

"""
    production_sector_pf(name, activities, factors, commodities; params)

Production with sector-level production and factor pricing.

Use when factor prices are activity-specific or when factor markets are
cleared outside the block. Parameters mirror the Leontief/Cobb-Douglas
structure used in standard production blocks.
"""
production_sector_pf(name::Symbol, activities::Vector{Symbol}, factors::Vector{Symbol}, commodities::Vector{Symbol};
    params::NamedTuple) =
    ProductionCDLeontiefSectorPFBlock(name, activities, factors, commodities, params)

"""
    production_multilabor_cd(name, activities, labor; params)

Multi-labor Cobb-Douglas production block.

Parameters:
- `beta[lc,i]` labor shares by labor type and activity.
- `b[i]` scale parameters (if used).
"""
production_multilabor_cd(name::Symbol, activities::Vector{Symbol}, labor::Vector{Symbol}; params::NamedTuple) =
    ProductionMultilaborCDBlock(name, activities, labor, params)

"""
    factor_supply(name, factors; params)

Factor supply block for endowment or supply curves.

Parameters:
- `FF[h]` or `endowment[h]` for fixed supplies.
- Optional elasticities for upward-sloping supply.

Variables:
- `FF[h]` (supply) and `pf[h]` (price).
"""
factor_supply(name::Symbol, factors::Vector{Symbol}, params::NamedTuple) =
    FactorSupplyBlock(name, factors, params)

"""
    household_demand(name, households, commodities, factors; form=:cd, consumption_var=:Xp, params)

Household demand block with selectable utility form.

Arguments:
- `form`: utility form symbol (e.g., `:cd`).
- `consumption_var`: name of consumption variable (default `:Xp`).

Parameters (typical):
- `alpha[i,hh]` budget shares.
- `FF[h,hh]` factor endowments by household.
- Optional taxes/transfers depending on model.

Variables:
- `Xp[i,hh]` consumption, `Y[hh]` income, `pf[h]` factor prices.
"""
household_demand(name::Symbol, households::Vector{Symbol}, commodities::Vector{Symbol}, factors::Vector{Symbol};
    form::Symbol=:cd, consumption_var::Symbol=:Xp, params::NamedTuple) =
    HouseholdDemandBlock(name, households, commodities, factors, form, consumption_var, params)

"""
    household_demand_regional(name, commodities, factors, region; params)

Regional household demand block (Cobb-Douglas over `:Xp` by region).

Parameters mirror `household_demand` but are indexed by region.
"""
household_demand_regional(name::Symbol, commodities::Vector{Symbol}, factors::Vector{Symbol}, region::Symbol;
    params::NamedTuple) =
    HouseholdDemandCDXpRegionalBlock(name, commodities, factors, region, params)

"""
    household_demand_income(name, commodities, factors, activities; params)

Household demand driven by income identity over factor payments.

This block is useful when household income is computed from activity
factor payments rather than endowments.
"""
household_demand_income(name::Symbol, commodities::Vector{Symbol}, factors::Vector{Symbol}, activities::Vector{Symbol};
    params::NamedTuple) =
    HouseholdDemandIncomeBlock(name, commodities, factors, activities, params)

"""
    household_share_demand_hh(name, households, commodities; params)

Household demand with explicit budget shares by household.

Parameters:
- `alpha[i,hh]` shares that sum to one per household.
"""
household_share_demand_hh(name::Symbol, households::Vector{Symbol}, commodities::Vector{Symbol}; params::NamedTuple) =
    HouseholdShareDemandHHBlock(name, households, commodities, params)

"""
    household_income_labor_capital(name, households, activities, labor; params)

Household income from labor and capital sources.

Parameters:
- Labor income shares or mappings by household/activity.
"""
household_income_labor_capital(name::Symbol, households::Vector{Symbol}, activities::Vector{Symbol}, labor::Vector{Symbol};
    params::NamedTuple) =
    HouseholdIncomeLaborCapitalBlock(name, households, activities, labor, params)

"""
    household_tax_revenue(name, households; params)

Household tax revenue block.

Parameters:
- `tau_d[hh]` or equivalent direct tax rates.
"""
household_tax_revenue(name::Symbol, households::Vector{Symbol}; params::NamedTuple) =
    HouseholdTaxRevenueBlock(name, households, params)

"""
    household_income_sum(name, households; params=(;))

Aggregate household income identity across households.
"""
household_income_sum(name::Symbol, households::Vector{Symbol}; params::NamedTuple=(;)) =
    HouseholdIncomeSumBlock(name, households, params)

"""
    activity_analysis(name, activities, commodities; params)

Activity analysis block with fixed input/output coefficients.

Required params:
- `a_in[g,s]`, `a_out[g,s]` by commodity and activity.

Variables:
- `X[g,s]` inputs, `Z[g,s]` outputs, `Y[s]` activity level, `pq[g]` prices.
"""
activity_analysis(name::Symbol, activities::Vector{Symbol}, commodities::Vector{Symbol}; params::NamedTuple) =
    ActivityAnalysisBlock(name, activities, commodities, params)

"""
    consumer_endowment_cd(name, consumers, commodities; params)

Consumer endowment + Cobb-Douglas demand block.

Required params:
- `alpha[g,c]` budget shares.
- `endowment[g,c]` commodity endowments.
"""
consumer_endowment_cd(name::Symbol, consumers::Vector{Symbol}, commodities::Vector{Symbol}; params::NamedTuple) =
    ConsumerEndowmentCDBlock(name, consumers, commodities, params)

"""
    commodity_market_clearing(name, commodities, activities, consumers; params)

Market clearing for commodities with activity outputs and consumer demands.

Parameters:
- `endowment[g,c]` for consumer endowments (if used).

Equations:
- `eqMC[g]` with complementarity on `pq[g]` when MCP is enabled.
"""
commodity_market_clearing(name::Symbol, commodities::Vector{Symbol}, activities::Vector{Symbol}, consumers::Vector{Symbol}; params::NamedTuple) =
    CommodityMarketClearingBlock(name, commodities, activities, consumers, params)

"""
    market_clearing(name, commodities, factors)

Joint market clearing for commodities and factors.

Equations:
- `eqQ[i]`: composite good clearing.
- `eqF[h]`: factor market clearing.

Variables:
- `Q[i]`, `Xp[i,hh]`, `Xg[i]`, `Xv[i]`, `X[i,j]`
- `FF[h]`, `F[h,j]`
"""
market_clearing(name::Symbol, commodities::Vector{Symbol}, factors::Vector{Symbol}) =
    MarketClearingBlock(name, commodities, factors)

"""
    goods_market_clearing(name, commodities)

Market clearing for goods with supply equal to demand.

Equations:
- `eqX[i]`: `X[i] == Z[i]`-style clearing.
"""
goods_market_clearing(name::Symbol, commodities::Vector{Symbol}) =
    GoodsMarketClearingBlock(name, commodities)

"""
    factor_market_clearing(name, activities, factors; params=(;))

Market clearing for factors across activities.

Equations:
- `eqF[h]`: sum of factor demands equals endowment.
"""
factor_market_clearing(name::Symbol, activities::Vector{Symbol}, factors::Vector{Symbol}; params::NamedTuple=(;)) =
    FactorMarketClearingBlock(name, activities, factors, params)

"""
    composite_market_clearing(name, commodities, activities)

Market clearing for composite goods (e.g., Armington aggregates).
"""
composite_market_clearing(name::Symbol, commodities::Vector{Symbol}, activities::Vector{Symbol}) =
    CompositeMarketClearingBlock(name, commodities, activities)

"""
    labor_market_clearing(name, labor, activities; params)

Labor market clearing by labor type across activities.
"""
labor_market_clearing(name::Symbol, labor::Vector{Symbol}, activities::Vector{Symbol}; params::NamedTuple) =
    LaborMarketClearingBlock(name, labor, activities, params)

"""
    price_link(name, commodities, params)

Link prices through wedges or policy parameters.

Typical params:
- ad-valorem taxes or margins that map `pz` to `pq` or `px`.
"""
price_link(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    PriceLinkBlock(name, commodities, params)

"""
    exchange_rate_link(name, commodities)

Link export/import prices to a single exchange rate.
"""
exchange_rate_link(name::Symbol, commodities::Vector{Symbol}) =
    ExchangeRateLinkBlock(name, commodities)

"""
    exchange_rate_link_region(name, commodities, region)

Link trade prices to a region-specific exchange rate.
"""
exchange_rate_link_region(name::Symbol, commodities::Vector{Symbol}, region::Symbol) =
    ExchangeRateLinkRegionBlock(name, commodities, region)

"""
    price_equality(name, commodities)

Enforce equality between demand and supply prices.
"""
price_equality(name::Symbol, commodities::Vector{Symbol}) =
    PriceEqualityBlock(name, commodities)

"""
    numeraire(name, kind, label, value)

Fix a numeraire variable.

`kind` can be `:commodity`, `:factor`, or `:exchange`. The matching price
variable is fixed at `value`.
"""
numeraire(name::Symbol, kind::Symbol, label::Symbol, value::Real) =
    NumeraireBlock(name, kind, label, value)

"""
    government(name, commodities, factors; params)

Government budget block with revenues and expenditures.

Typical params:
- `tau_d`, `tau_z`, `tau_m`, `mu` shares, and optional rents.
"""
government(name::Symbol, commodities::Vector{Symbol}, factors::Vector{Symbol}, params::NamedTuple) =
    GovernmentBlock(name, commodities, factors, params)

"""
    government_regional(name, commodities, factors, region; params)

Regional government budget block.
"""
government_regional(name::Symbol, commodities::Vector{Symbol}, factors::Vector{Symbol}, region::Symbol, params::NamedTuple) =
    GovernmentRegionalBlock(name, commodities, factors, region, params)

"""
    government_budget_balance(name, commodities; params)

Government budget balance equation (revenues minus savings).
"""
government_budget_balance(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    GovernmentBudgetBalanceBlock(name, commodities, params)

"""
    government_revenue(name, commodities; params)

Government revenue aggregation block.
"""
government_revenue(name::Symbol, commodities::Vector{Symbol}; params::NamedTuple) =
    GovernmentRevenueBlock(name, commodities, params)

"""
    private_saving(name, factors; params)

Private saving from factor incomes.
"""
private_saving(name::Symbol, factors::Vector{Symbol}, params::NamedTuple) =
    PrivateSavingBlock(name, factors, params)

"""
    private_saving_regional(name, factors, region; params)

Regional private saving block.
"""
private_saving_regional(name::Symbol, factors::Vector{Symbol}, region::Symbol, params::NamedTuple) =
    PrivateSavingRegionalBlock(name, factors, region, params)

"""
    private_saving_income(name, factors, activities; params)

Private saving from activity-level incomes.
"""
private_saving_income(name::Symbol, factors::Vector{Symbol}, activities::Vector{Symbol}, params::NamedTuple) =
    PrivateSavingIncomeBlock(name, factors, activities, params)

"""
    investment(name, commodities; params)

Investment demand block.
"""
investment(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    InvestmentBlock(name, commodities, params)

"""
    investment_regional(name, commodities, region; params)

Regional investment demand block.
"""
investment_regional(name::Symbol, commodities::Vector{Symbol}, region::Symbol, params::NamedTuple) =
    InvestmentRegionalBlock(name, commodities, region, params)

"""
    armington(name, commodities; params)

Armington CES composite of imports and domestic goods.

Parameters:
- `delta_m`, `delta_d`, `gamma`, `eta`, `tau_m`
"""
armington(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ArmingtonCESBlock(name, commodities, params)

"""
    transformation(name, commodities; params)

CET transformation between domestic supply and exports.

Parameters:
- `xie`, `xid`, `theta`, `phi`, `tau_z`
"""
transformation(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    TransformationCETBlock(name, commodities, params)

"""
    monopoly_rent(name, commodities; params)

Monopoly rent block for markup or rent extraction.
"""
monopoly_rent(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    MonopolyRentBlock(name, commodities, params)

"""
    import_quota(name, commodities; params)

Import quota block with complementarity on quota slack.
"""
import_quota(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ImportQuotaBlock(name, commodities, params)

"""
    mobile_factor_market(name, factors, activities)

Mobile factor market clearing across activities.
"""
mobile_factor_market(name::Symbol, factors::Vector{Symbol}, activities::Vector{Symbol}) =
    MobileFactorMarketBlock(name, factors, activities)

"""
    capital_stock_return(name, factor, activities; params)

Capital return block linking sectoral returns to a stock return.
"""
capital_stock_return(name::Symbol, factor::Symbol, activities::Vector{Symbol}, params::NamedTuple) =
    CapitalStockReturnBlock(name, factor, activities, params)

"""
    composite_investment(name, commodities, activities; params)

Composite investment aggregation over commodities.
"""
composite_investment(name::Symbol, commodities::Vector{Symbol}, activities::Vector{Symbol}, params::NamedTuple) =
    CompositeInvestmentBlock(name, commodities, activities, params)

"""
    investment_allocation(name, factor, activities; params)

Allocate investment to activities based on shares or returns.
"""
investment_allocation(name::Symbol, factor::Symbol, activities::Vector{Symbol}, params::NamedTuple) =
    InvestmentAllocationBlock(name, factor, activities, params)

"""
    composite_consumption(name, commodities; params)

Aggregate consumption bundle over commodities.
"""
composite_consumption(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    CompositeConsumptionBlock(name, commodities, params)

"""
    price_level(name, commodities; params)

Compute a price level index.
"""
price_level(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    PriceLevelBlock(name, commodities, params)

"""
    price_index(name, commodities; params)

Compute a price index (weighted average).
"""
price_index(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    PriceIndexBlock(name, commodities, params)

"""
    closure(name, params)

Closure block used to enforce macro closure identities.

Parameters depend on the closure rules (e.g., savings-investment,
government balance, external balance).
"""
closure(name::Symbol, params::NamedTuple) =
    ClosureBlock(name, params)

"""
    utility(name, households, commodities; form=:cd, consumption_var=:Xp, params)

Household utility block.

Parameters:
- `alpha[i,hh]` for Cobb-Douglas utility.
"""
utility(name::Symbol, households::Vector{Symbol}, commodities::Vector{Symbol};
    form::Symbol=:cd, consumption_var::Symbol=:Xp, params::NamedTuple) =
    UtilityBlock(name, households, commodities, form, consumption_var, params)

"""
    utility_regional(name, goods_by_region, params)

Regional utility aggregation block.

`goods_by_region` maps region => commodity list.
"""
utility_regional(name::Symbol, goods_by_region::Dict{Symbol,Vector{Symbol}}, params::NamedTuple) =
    UtilityCDRegionalBlock(name, goods_by_region, params)

"""
    external_balance(name, commodities; params)

External balance (BOP) block with fixed world prices.

Parameters typically include `pWe`, `pWm`, and foreign savings `Sf`.
"""
external_balance(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ExternalBalanceBlock(name, commodities, params)

"""
    external_balance_var_price(name, commodities; params)

External balance block with variable world prices or exchange rates.
"""
external_balance_var_price(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ExternalBalanceVarPriceBlock(name, commodities, params)

"""
    external_balance_remit(name, commodities; params)

External balance block including remittances.
"""
external_balance_remit(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ExternalBalanceRemitBlock(name, commodities, params)

"""
    foreign_trade(name, commodities; params)

Foreign trade block combining export demand and import supply.
"""
foreign_trade(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ForeignTradeBlock(name, commodities, params)

"""
    price_aggregation(name, commodities, activities; params)

Aggregate prices across activities or sources.
"""
price_aggregation(name::Symbol, commodities::Vector{Symbol}, activities::Vector{Symbol}, params::NamedTuple) =
    PriceAggregationBlock(name, commodities, activities, params)

"""
    international_market(name, goods, regions, mapping)

International market clearing with region-specific trade flows.

`mapping` maps (good, region) to a composite good identifier.
"""
international_market(name::Symbol, goods::Vector{Symbol}, regions::Vector{Symbol},
    mapping::Dict{Tuple{Symbol,Symbol},Symbol}) =
    InternationalMarketBlock(name, goods, regions, mapping)

"""
    activity_price_io(name, activities, commodities; params)

Activity price with input-output structure.
"""
activity_price_io(name::Symbol, activities::Vector{Symbol}, commodities::Vector{Symbol}, params::NamedTuple) =
    ActivityPriceIOBlock(name, activities, commodities, params)

"""
    capital_price_composition(name, activities, commodities; params)

Capital price composition from activity prices.
"""
capital_price_composition(name::Symbol, activities::Vector{Symbol}, commodities::Vector{Symbol}, params::NamedTuple) =
    CapitalPriceCompositionBlock(name, activities, commodities, params)

"""
    trade_price_link(name, commodities; params)

Link domestic prices to trade prices with wedges.
"""
trade_price_link(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    TradePriceLinkBlock(name, commodities, params)

"""
    import_premium_income(name, commodities; params)

Import premium income block.
"""
import_premium_income(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ImportPremiumIncomeBlock(name, commodities, params)

"""
    absorption_sales(name, commodities; params)

Absorption and sales identities for commodities.
"""
absorption_sales(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    AbsorptionSalesBlock(name, commodities, params)

"""
    armington_m_xxd(name, commodities; params)

Armington block with explicit M/XXD split.
"""
armington_m_xxd(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ArmingtonMXxdBlock(name, commodities, params)

"""
    cet_xxd_e(name, commodities; params)

CET block with explicit domestic/export split.
"""
cet_xxd_e(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    CETXXDEBlock(name, commodities, params)

"""
    export_demand(name, commodities; params)

Export demand block for foreign demand functions.
"""
export_demand(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ExportDemandBlock(name, commodities, params)

"""
    nontraded_supply(name, commodities; params)

Non-traded supply block for domestic-only goods.
"""
nontraded_supply(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    NontradedSupplyBlock(name, commodities, params)

"""
    household_share_demand(name, commodities; params)

Household share demand across commodities.
"""
household_share_demand(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    HouseholdShareDemandBlock(name, commodities, params)

"""
    government_share_demand(name, commodities; params)

Government demand by fixed shares.
"""
government_share_demand(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    GovernmentShareDemandBlock(name, commodities, params)

"""
    inventory_demand(name, commodities; params)

Inventory demand block.
"""
inventory_demand(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    InventoryDemandBlock(name, commodities, params)

"""
    government_finance(name, commodities; params)

Government finance block including taxes and savings.
"""
government_finance(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    GovernmentFinanceBlock(name, commodities, params)

"""
    gdp_income(name, activities; params)

GDP income aggregation block.
"""
gdp_income(name::Symbol, activities::Vector{Symbol}, params::NamedTuple) =
    GDPIncomeBlock(name, activities, params)

"""
    savings_investment(name, activities, commodities; params)

Savings-investment balance block.
"""
savings_investment(name::Symbol, activities::Vector{Symbol}, commodities::Vector{Symbol}, params::NamedTuple) =
    SavingsInvestmentBlock(name, activities, commodities, params)

"""
    final_demand_clearing(name, commodities; params)

Final demand market clearing block.
"""
final_demand_clearing(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    FinalDemandClearingBlock(name, commodities, params)

"""
    consumption_objective(name, commodities; params)

Consumption objective (utility) block for optimization.
"""
consumption_objective(name::Symbol, commodities::Vector{Symbol}, params::NamedTuple) =
    ConsumptionObjectiveBlock(name, commodities, params)

"""
    initial_values(name, params)

Initial values and bounds helper block.

Parameters:
- `start`, `lower`, `upper`, `fixed` dictionaries by variable symbol.
"""
initial_values(name::Symbol, params::NamedTuple) =
    InitialValuesBlock(name, params)

struct ProductionBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    factors::Vector{Symbol}
    commodities::Vector{Symbol}
    form::Union{Symbol,Dict{Symbol,Symbol}}
    params::NamedTuple
end

struct ProductionCDBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    factors::Vector{Symbol}
    params::NamedTuple
end

struct ProductionCDLeontiefBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    factors::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ProductionCDLeontiefSectorPFBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    factors::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ProductionMultilaborCDBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    labor::Vector{Symbol}
    params::NamedTuple
end

struct FactorSupplyBlock <: JCGECore.AbstractBlock
    name::Symbol
    factors::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdDemandBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    form::Symbol
    consumption_var::Symbol
    params::NamedTuple
end

struct HouseholdDemandCDBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdDemandCDXpBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdDemandCDHHBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdDemandCDXpRegionalBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    region::Symbol
    params::NamedTuple
end

struct HouseholdDemandIncomeBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    activities::Vector{Symbol}
    params::NamedTuple
end

struct ActivityAnalysisBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ConsumerEndowmentCDBlock <: JCGECore.AbstractBlock
    name::Symbol
    consumers::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct CommodityMarketClearingBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    activities::Vector{Symbol}
    consumers::Vector{Symbol}
    params::NamedTuple
end

struct MarketClearingBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
end

struct GoodsMarketClearingBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
end

struct FactorMarketClearingBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    factors::Vector{Symbol}
    params::NamedTuple
end

struct CompositeMarketClearingBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    activities::Vector{Symbol}
end

struct LaborMarketClearingBlock <: JCGECore.AbstractBlock
    name::Symbol
    labor::Vector{Symbol}
    activities::Vector{Symbol}
    params::NamedTuple
end

struct PriceLinkBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ExchangeRateLinkBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
end

struct ExchangeRateLinkRegionBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    region::Symbol
end

struct PriceEqualityBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
end

struct NumeraireBlock <: JCGECore.AbstractBlock
    name::Symbol
    kind::Symbol
    label::Symbol
    value::Float64
end

struct GovernmentBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    params::NamedTuple
end

struct GovernmentRegionalBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    factors::Vector{Symbol}
    region::Symbol
    params::NamedTuple
end

struct GovernmentBudgetBalanceBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct PrivateSavingBlock <: JCGECore.AbstractBlock
    name::Symbol
    factors::Vector{Symbol}
    params::NamedTuple
end

struct PrivateSavingRegionalBlock <: JCGECore.AbstractBlock
    name::Symbol
    factors::Vector{Symbol}
    region::Symbol
    params::NamedTuple
end

struct PrivateSavingIncomeBlock <: JCGECore.AbstractBlock
    name::Symbol
    factors::Vector{Symbol}
    activities::Vector{Symbol}
    params::NamedTuple
end

struct InvestmentBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct InvestmentRegionalBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    region::Symbol
    params::NamedTuple
end
struct ArmingtonCESBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct TransformationCETBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct MonopolyRentBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ImportQuotaBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct MobileFactorMarketBlock <: JCGECore.AbstractBlock
    name::Symbol
    factors::Vector{Symbol}
    activities::Vector{Symbol}
end

struct CapitalStockReturnBlock <: JCGECore.AbstractBlock
    name::Symbol
    factor::Symbol
    activities::Vector{Symbol}
    params::NamedTuple
end

struct CompositeInvestmentBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    activities::Vector{Symbol}
    params::NamedTuple
end

struct InvestmentAllocationBlock <: JCGECore.AbstractBlock
    name::Symbol
    factor::Symbol
    activities::Vector{Symbol}
    params::NamedTuple
end

struct CompositeConsumptionBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct PriceLevelBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ClosureBlock <: JCGECore.AbstractBlock
    name::Symbol
    params::NamedTuple
end

struct UtilityBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    commodities::Vector{Symbol}
    form::Symbol
    consumption_var::Symbol
    params::NamedTuple
end

struct UtilityCDBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct UtilityCDXpBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct UtilityCDHHBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct UtilityCDRegionalBlock <: JCGECore.AbstractBlock
    name::Symbol
    goods_by_region::Dict{Symbol,Vector{Symbol}}
    params::NamedTuple
end

struct ExternalBalanceBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ExternalBalanceVarPriceBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ForeignTradeBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct PriceAggregationBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    activities::Vector{Symbol}
    params::NamedTuple
end

struct InternationalMarketBlock <: JCGECore.AbstractBlock
    name::Symbol
    goods::Vector{Symbol}
    regions::Vector{Symbol}
    mapping::Dict{Tuple{Symbol,Symbol},Symbol}
end

struct ActivityPriceIOBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct CapitalPriceCompositionBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct TradePriceLinkBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct AbsorptionSalesBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ArmingtonMXxdBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct CETXXDEBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ExportDemandBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct NontradedSupplyBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdShareDemandBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdShareDemandHHBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdIncomeLaborCapitalBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    activities::Vector{Symbol}
    labor::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdTaxRevenueBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    params::NamedTuple
end

struct HouseholdIncomeSumBlock <: JCGECore.AbstractBlock
    name::Symbol
    households::Vector{Symbol}
    params::NamedTuple
end

struct GovernmentShareDemandBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct InventoryDemandBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct GovernmentFinanceBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct GovernmentRevenueBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct GDPIncomeBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    params::NamedTuple
end

struct SavingsInvestmentBlock <: JCGECore.AbstractBlock
    name::Symbol
    activities::Vector{Symbol}
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct FinalDemandClearingBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ConsumptionObjectiveBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ImportPremiumIncomeBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct ExternalBalanceRemitBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct PriceIndexBlock <: JCGECore.AbstractBlock
    name::Symbol
    commodities::Vector{Symbol}
    params::NamedTuple
end

struct InitialValuesBlock <: JCGECore.AbstractBlock
    name::Symbol
    params::NamedTuple
end

function _expr_or_raw(info, expr)
    if expr !== nothing
        return expr
    end
    if info === nothing
        return ERaw("(no info)")
    end
    return ERaw(string(info))
end

function _payload_params(block)
    return hasproperty(block, :params) ? getproperty(block, :params) : nothing
end

function _build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense)
    payload = (
        indices=idxs,
        index_names=index_names,
        params=_payload_params(block),
        info=info,
        expr=_expr_or_raw(info, expr),
        constraint=constraint,
    )
    if mcp_var !== nothing
        payload = merge(payload, (mcp_var=mcp_var,))
    end
    if objective_expr !== nothing
        payload = merge(payload, (objective_expr=objective_expr, objective_sense=objective_sense))
    end
    return payload
end

function global_var(base::Symbol, idxs::Symbol...)
    if isempty(idxs)
        return base
    end
    return Symbol(string(base), "_", join(string.(idxs), "_"))
end

function var_name(block::FactorSupplyBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::FactorSupplyBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ActivityAnalysisBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ActivityAnalysisBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ConsumerEndowmentCDBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ConsumerEndowmentCDBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::CommodityMarketClearingBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::CommodityMarketClearingBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::HouseholdDemandCDHHBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::HouseholdDemandCDHHBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::HouseholdDemandCDBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::HouseholdDemandCDXpBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::HouseholdDemandCDXpRegionalBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::HouseholdDemandIncomeBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::HouseholdDemandIncomeBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::MarketClearingBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::MarketClearingBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::GoodsMarketClearingBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::FactorMarketClearingBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::CompositeMarketClearingBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::PriceLinkBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PriceLinkBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ExchangeRateLinkBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ExchangeRateLinkRegionBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PriceEqualityBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::NumeraireBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::NumeraireBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::GovernmentBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::GovernmentBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::GovernmentRegionalBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::GovernmentBudgetBalanceBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::GovernmentBudgetBalanceBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PrivateSavingBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PrivateSavingRegionalBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::PrivateSavingIncomeBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PrivateSavingIncomeBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::InvestmentBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::InvestmentBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::InvestmentRegionalBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ArmingtonCESBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ArmingtonCESBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::TransformationCETBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::TransformationCETBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::MonopolyRentBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::MonopolyRentBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ImportQuotaBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ImportQuotaBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::MobileFactorMarketBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::MobileFactorMarketBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::CapitalStockReturnBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::CapitalStockReturnBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::CompositeInvestmentBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::CompositeInvestmentBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::InvestmentAllocationBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::InvestmentAllocationBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::CompositeConsumptionBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::CompositeConsumptionBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::PriceLevelBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PriceLevelBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::PriceIndexBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PriceIndexBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ClosureBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ClosureBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::UtilityBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::UtilityBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::UtilityCDBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::UtilityCDXpBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::UtilityCDHHBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::UtilityCDRegionalBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ExternalBalanceRemitBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ExternalBalanceRemitBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ExternalBalanceBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ExternalBalanceBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ExternalBalanceVarPriceBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ForeignTradeBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::PriceAggregationBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::PriceAggregationBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::InternationalMarketBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::InitialValuesBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ProductionCDLeontiefBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function ensure_var!(ctx::JCGERuntime.KernelContext, model, name::Symbol; lower=0.00001, start=nothing)
    if haskey(ctx.variables, name)
        return ctx.variables[name]
    end
    if model isa JuMP.Model
        if start === nothing
            v = @variable(model, lower_bound=lower, base_name=string(name))
        else
            v = @variable(model, lower_bound=lower, base_name=string(name), start=start)
        end
    else
        v = (name=name)
    end
    JCGERuntime.register_variable!(ctx, name, v)
    return v
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ProductionCDLeontiefBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function var_name(block::ProductionCDLeontiefSectorPFBlock, base::Symbol, idxs::Symbol...)
    return global_var(base, idxs...)
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ProductionCDLeontiefSectorPFBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function register_eq!(ctx::JCGERuntime.KernelContext, block::ProductionCDBlock, tag::Symbol, idxs::Symbol...; info=nothing, expr=nothing, index_names=nothing, constraint=nothing, mcp_var=nothing, objective_expr=nothing, objective_sense=nothing)
    JCGERuntime.register_equation!(ctx; tag=tag, block=block.name, payload=_build_payload(block, idxs, index_names, info, expr, constraint, mcp_var, objective_expr, objective_sense))
    return nothing
end

function JCGECore.build!(block::ProductionCDLeontiefBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities

    model = ctx.model
    Y = Dict{Symbol,Any}()
    Z = Dict{Symbol,Any}()
    py = Dict{Symbol,Any}()
    pz = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()
    F = Dict{Tuple{Symbol,Symbol},Any}()
    X = Dict{Tuple{Symbol,Symbol},Any}()

    for i in activities
        Y[i] = ensure_var!(ctx, model, var_name(block, :Y, i))
        Z[i] = ensure_var!(ctx, model, var_name(block, :Z, i))
        py[i] = ensure_var!(ctx, model, var_name(block, :py, i))
        pz[i] = ensure_var!(ctx, model, var_name(block, :pz, i))
    end

    for j in commodities
        pq[j] = ensure_var!(ctx, model, var_name(block, :pq, j))
    end

    for h in factors
        pf[h] = ensure_var!(ctx, model, var_name(block, :pf, h))
    end

    for h in factors, i in activities
        F[(h, i)] = ensure_var!(ctx, model, var_name(block, :F, h, i))
    end

    for j in commodities, i in activities
        X[(j, i)] = ensure_var!(ctx, model, var_name(block, :X, j, i))
    end

    for i in activities
        b_i = JCGECore.getparam(block.params, :b, i)
        beta_vals = Dict(h => JCGECore.getparam(block.params, :beta, h, i) for h in factors)
        ay_i = JCGECore.getparam(block.params, :ay, i)
        ax_vals = Dict(j => JCGECore.getparam(block.params, :ax, j, i) for j in commodities)

        constraint = nothing
        expr = EEq(
            EVar(:Y, Any[EIndex(:i)]),
            EMul([
                EParam(:b, Any[EIndex(:i)]),
                EProd(:h, factors,
                    EPow(
                        EVar(:F, Any[EIndex(:h), EIndex(:i)]),
                        EParam(:beta, Any[EIndex(:h), EIndex(:i)]),
                    ),
                ),
            ]),
        )
        register_eq!(ctx, block, :eqpy, i;
            info="Y[i] == b[i] * prod(F[h,i]^beta[h,i])", expr=expr, index_names=(:i,), constraint=constraint)

        for h in factors
            constraint = nothing
            expr = EEq(
                EVar(:F, Any[EIndex(:h), EIndex(:i)]),
                EDiv(
                    EMul([
                        EParam(:beta, Any[EIndex(:h), EIndex(:i)]),
                        EVar(:py, Any[EIndex(:i)]),
                        EVar(:Y, Any[EIndex(:i)]),
                    ]),
                    EVar(:pf, Any[EIndex(:h)]),
                ),
            )
            register_eq!(ctx, block, :eqF, h, i;
                info="F[h,i] == beta[h,i] * py[i] * Y[i] / pf[h]",
                expr=expr, index_names=(:h, :i), constraint=constraint)
        end

        for j in commodities
            constraint = nothing
            expr = EEq(
                EVar(:X, Any[EIndex(:j), EIndex(:i)]),
                EMul([
                    EParam(:ax, Any[EIndex(:j), EIndex(:i)]),
                    EVar(:Z, Any[EIndex(:i)]),
                ]),
            )
            register_eq!(ctx, block, :eqX, j, i;
                info="X[j,i] == ax[j,i] * Z[i]", expr=expr, index_names=(:j, :i), constraint=constraint)
        end

        constraint = nothing
        expr = EEq(
            EVar(:Y, Any[EIndex(:i)]),
            EMul([
                EParam(:ay, Any[EIndex(:i)]),
                EVar(:Z, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqY, i; info="Y[i] == ay[i] * Z[i]", expr=expr, index_names=(:i,), constraint=constraint)

        fc_term = hasproperty(block.params, :FC) ? JCGECore.getparam(block.params, :FC, i) / Z[i] : 0.0
        constraint = nothing
        fc_expr = hasproperty(block.params, :FC) ? EDiv(EParam(:FC, Any[EIndex(:i)]), EVar(:Z, Any[EIndex(:i)])) : EConst(0.0)
        expr = EEq(
            EVar(:pz, Any[EIndex(:i)]),
            EAdd([
                EMul([
                    EParam(:ay, Any[EIndex(:i)]),
                    EVar(:py, Any[EIndex(:i)]),
                ]),
                ESum(:j, commodities, EMul([
                    EParam(:ax, Any[EIndex(:j), EIndex(:i)]),
                    EVar(:pq, Any[EIndex(:j)]),
                ])),
                fc_expr,
            ]),
        )
        register_eq!(ctx, block, :eqpzs, i;
            info="pz[i] == ay[i]*py[i] + sum(ax[j,i]*pq[j]) + FC[i]/Z[i]",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::ProductionCDLeontiefSectorPFBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities

    model = ctx.model
    Y = Dict{Symbol,Any}()
    Z = Dict{Symbol,Any}()
    py = Dict{Symbol,Any}()
    pz = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Tuple{Symbol,Symbol},Any}()
    F = Dict{Tuple{Symbol,Symbol},Any}()
    X = Dict{Tuple{Symbol,Symbol},Any}()

    for i in activities
        Y[i] = ensure_var!(ctx, model, var_name(block, :Y, i))
        Z[i] = ensure_var!(ctx, model, var_name(block, :Z, i))
        py[i] = ensure_var!(ctx, model, var_name(block, :py, i))
        pz[i] = ensure_var!(ctx, model, var_name(block, :pz, i))
    end

    for j in commodities
        pq[j] = ensure_var!(ctx, model, var_name(block, :pq, j))
    end

    for h in factors, i in activities
        pf[(h, i)] = ensure_var!(ctx, model, var_name(block, :pf, h, i))
        F[(h, i)] = ensure_var!(ctx, model, var_name(block, :F, h, i))
    end

    for j in commodities, i in activities
        X[(j, i)] = ensure_var!(ctx, model, var_name(block, :X, j, i))
    end

    for i in activities
        b_i = JCGECore.getparam(block.params, :b, i)
        beta_vals = Dict(h => JCGECore.getparam(block.params, :beta, h, i) for h in factors)
        ay_i = JCGECore.getparam(block.params, :ay, i)
        ax_vals = Dict(j => JCGECore.getparam(block.params, :ax, j, i) for j in commodities)

        constraint = nothing
        expr = EEq(
            EVar(:Y, Any[EIndex(:i)]),
            EMul([
                EParam(:b, Any[EIndex(:i)]),
                EProd(:h, factors,
                    EPow(
                        EVar(:F, Any[EIndex(:h), EIndex(:i)]),
                        EParam(:beta, Any[EIndex(:h), EIndex(:i)]),
                    ),
                ),
            ]),
        )
        register_eq!(ctx, block, :eqpy, i;
            info="Y[i] == b[i] * prod(F[h,i]^beta[h,i])", expr=expr, index_names=(:i,), constraint=constraint)

        for h in factors
            constraint = nothing
            expr = EEq(
                EVar(:F, Any[EIndex(:h), EIndex(:i)]),
                EDiv(
                    EMul([
                        EParam(:beta, Any[EIndex(:h), EIndex(:i)]),
                        EVar(:py, Any[EIndex(:i)]),
                        EVar(:Y, Any[EIndex(:i)]),
                    ]),
                    EVar(:pf, Any[EIndex(:h), EIndex(:i)]),
                ),
            )
            register_eq!(ctx, block, :eqF, h, i;
                info="F[h,i] == beta[h,i] * py[i] * Y[i] / pf[h,i]",
                expr=expr, index_names=(:h, :i), constraint=constraint)
        end

        for j in commodities
            constraint = nothing
            expr = EEq(
                EVar(:X, Any[EIndex(:j), EIndex(:i)]),
                EMul([
                    EParam(:ax, Any[EIndex(:j), EIndex(:i)]),
                    EVar(:Z, Any[EIndex(:i)]),
                ]),
            )
            register_eq!(ctx, block, :eqX, j, i;
                info="X[j,i] == ax[j,i] * Z[i]", expr=expr, index_names=(:j, :i), constraint=constraint)
        end

        constraint = nothing
        expr = EEq(
            EVar(:Y, Any[EIndex(:i)]),
            EMul([
                EParam(:ay, Any[EIndex(:i)]),
                EVar(:Z, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqY, i; info="Y[i] == ay[i] * Z[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:pz, Any[EIndex(:i)]),
            EAdd([
                EMul([
                    EParam(:ay, Any[EIndex(:i)]),
                    EVar(:py, Any[EIndex(:i)]),
                ]),
                ESum(:j, commodities, EMul([
                    EParam(:ax, Any[EIndex(:j), EIndex(:i)]),
                    EVar(:pq, Any[EIndex(:j)]),
                ])),
            ]),
        )
        register_eq!(ctx, block, :eqpzs, i;
            info="pz[i] == ay[i]*py[i] + sum(ax[j,i]*pq[j])",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::ProductionCDBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Z = Dict{Symbol,Any}()
    pz = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()
    F = Dict{Tuple{Symbol,Symbol},Any}()

    for j in activities
        Z[j] = ensure_var!(ctx, model, global_var(:Z, j))
        pz[j] = ensure_var!(ctx, model, global_var(:pz, j))
    end
    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
    end
    for h in factors, j in activities
        F[(h, j)] = ensure_var!(ctx, model, global_var(:F, h, j))
    end

    for j in activities
        b_j = JCGECore.getparam(block.params, :b, j)
        beta_vals = Dict(h => JCGECore.getparam(block.params, :beta, h, j) for h in factors)
        constraint = nothing
        expr = EEq(
            EVar(:Z, Any[EIndex(:j)]),
            EMul([
                EParam(:b, Any[EIndex(:j)]),
                EProd(:h, factors,
                    EPow(
                        EVar(:F, Any[EIndex(:h), EIndex(:j)]),
                        EParam(:beta, Any[EIndex(:h), EIndex(:j)]),
                    ),
                ),
            ]),
        )
        register_eq!(ctx, block, :eqZ, j;
            info="Z[j] == b[j] * prod(F[h,j]^beta[h,j])", expr=expr, index_names=(:j,), constraint=constraint)

        for h in factors
            constraint = nothing
            expr = EEq(
                EVar(:F, Any[EIndex(:h), EIndex(:j)]),
                EDiv(
                    EMul([
                        EParam(:beta, Any[EIndex(:h), EIndex(:j)]),
                        EVar(:pz, Any[EIndex(:j)]),
                        EVar(:Z, Any[EIndex(:j)]),
                    ]),
                    EVar(:pf, Any[EIndex(:h)]),
                ),
            )
            register_eq!(ctx, block, :eqF, h, j;
                info="F[h,j] == beta[h,j] * pz[j] * Z[j] / pf[h]", expr=expr, index_names=(:h, :j), constraint=constraint)
        end
    end

    return nothing
end

function JCGECore.build!(block::ProductionBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    form_map = block.form isa Symbol ? Dict(a => block.form for a in activities) : block.form
    if !(form_map isa Dict{Symbol,Symbol})
        error("ProductionBlock.form must be Symbol or Dict{Symbol,Symbol}")
    end
    for a in activities
        haskey(form_map, a) || error("Missing production form for activity $(a)")
        form = form_map[a]
        if form == :cd
            inner = ProductionCDBlock(block.name, [a], block.factors, block.params)
            JCGECore.build!(inner, ctx, spec)
        elseif form == :cd_leontief
            inner = ProductionCDLeontiefBlock(block.name, [a], block.factors, block.commodities, block.params)
            JCGECore.build!(inner, ctx, spec)
        else
            error("Unsupported production form: $(form)")
        end
    end
    return nothing
end

function JCGECore.build!(block::FactorSupplyBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    for h in factors
        var = ensure_var!(ctx, model, var_name(block, :FF, h))
        ff_h = JCGECore.getparam(block.params, :FF, h)
        constraint = nothing
        expr = EEq(EVar(:FF, Any[EIndex(:h)]), EParam(:FF, Any[EIndex(:h)]))
        register_eq!(ctx, block, :eqFF, h;
            info="FF[h] == endowment[h]", expr=expr, index_names=(:h,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::HouseholdDemandCDHHBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    households = isempty(block.households) ? spec.model.sets.institutions : block.households
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Xp = Dict{Tuple{Symbol,Symbol},Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()
    Sp = Dict{Symbol,Any}()
    Td = Dict{Symbol,Any}()
    Y = Dict{Symbol,Any}()

    for i in commodities
        pq[i] = ensure_var!(ctx, model, var_name(block, :pq, i))
    end

    for h in factors
        pf[h] = ensure_var!(ctx, model, var_name(block, :pf, h))
    end

    for hh in households
        Sp[hh] = ensure_var!(ctx, model, var_name(block, :Sp, hh))
        Td[hh] = ensure_var!(ctx, model, var_name(block, :Td, hh))
        Y[hh] = ensure_var!(ctx, model, var_name(block, :Y, hh))
    end

    for i in commodities, hh in households
        Xp[(i, hh)] = ensure_var!(ctx, model, var_name(block, :Xp, i, hh))
    end

    for hh in households
        ff_vals = Dict(h => JCGECore.getparam(block.params, :FF, h, hh) for h in factors)
        ssp_hh = JCGECore.getparam(block.params, :ssp, hh)
        tau_d_hh = JCGECore.getparam(block.params, :tau_d, hh)
        alpha_vals = Dict(i => JCGECore.getparam(block.params, :alpha, i, hh) for i in commodities)

        constraint = nothing
        expr = EEq(
            EVar(:Y, Any[EIndex(:hh)]),
            ESum(:h, factors, EMul([
                EVar(:pf, Any[EIndex(:h)]),
                EParam(:FF, Any[EIndex(:h), EIndex(:hh)]),
            ])),
        )
        register_eq!(ctx, block, :eqY, hh;
            info="Y[hh] == sum(pf[h] * FF[h,hh])", expr=expr, index_names=(:hh,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:Sp, Any[EIndex(:hh)]),
            EMul([
                EParam(:ssp, Any[EIndex(:hh)]),
                EVar(:Y, Any[EIndex(:hh)]),
            ]),
        )
        register_eq!(ctx, block, :eqSp, hh;
            info="Sp[hh] == ssp[hh] * Y[hh]", expr=expr, index_names=(:hh,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:Td, Any[EIndex(:hh)]),
            EMul([
                EParam(:tau_d, Any[EIndex(:hh)]),
                EVar(:Y, Any[EIndex(:hh)]),
            ]),
        )
        register_eq!(ctx, block, :eqTd, hh;
            info="Td[hh] == tau_d[hh] * Y[hh]", expr=expr, index_names=(:hh,), constraint=constraint)

        for i in commodities
            constraint = nothing
            expr = EEq(
                EVar(:Xp, Any[EIndex(:i), EIndex(:hh)]),
                EDiv(
                    EMul([
                        EParam(:alpha, Any[EIndex(:i), EIndex(:hh)]),
                        EAdd([
                            EVar(:Y, Any[EIndex(:hh)]),
                            ENeg(EVar(:Sp, Any[EIndex(:hh)])),
                            ENeg(EVar(:Td, Any[EIndex(:hh)])),
                        ]),
                    ]),
                    EVar(:pq, Any[EIndex(:i)]),
                ),
            )
            register_eq!(ctx, block, :eqXp, i, hh;
                info="Xp[i,hh] == alpha[i,hh] * (Y - Sp - Td) / pq[i]",
                expr=expr, index_names=(:i, :hh), constraint=constraint)
        end
    end

    return nothing
end

function JCGECore.build!(block::HouseholdDemandCDBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    X = Dict{Symbol,Any}()
    px = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()

    for i in commodities
        X[i] = ensure_var!(ctx, model, global_var(:X, i))
        px[i] = ensure_var!(ctx, model, global_var(:px, i))
    end
    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
    end

    ff_vals = Dict(h => JCGECore.getparam(block.params, :FF, h) for h in factors)
    for i in commodities
        alpha_i = JCGECore.getparam(block.params, :alpha, i)
        constraint = nothing
        expr = EEq(
            EVar(:X, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:alpha, Any[EIndex(:i)]),
                    ESum(:h, factors, EMul([
                        EVar(:pf, Any[EIndex(:h)]),
                        EParam(:FF, Any[EIndex(:h)]),
                    ])),
                ]),
                EVar(:px, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqX, i;
            info="X[i] == alpha[i] * sum(pf[h]*FF[h]) / px[i]",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::HouseholdDemandCDXpBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Xp = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()
    Sp = ensure_var!(ctx, model, global_var(:Sp))
    Td = ensure_var!(ctx, model, global_var(:Td))
    RT = Dict{Symbol,Any}()
    include_rent = hasproperty(block.params, :include_rent) && getproperty(block.params, :include_rent)
    include_fc = hasproperty(block.params, :include_fc) && getproperty(block.params, :include_fc)
    include_fc = hasproperty(block.params, :include_fc) && getproperty(block.params, :include_fc)

    for i in commodities
        Xp[i] = ensure_var!(ctx, model, global_var(:Xp, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
        if include_rent
            RT[i] = ensure_var!(ctx, model, global_var(:RT, i))
        end
    end
    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
    end

    ff_vals = Dict(h => JCGECore.getparam(block.params, :FF, h) for h in factors)
    for i in commodities
        alpha_i = JCGECore.getparam(block.params, :alpha, i)
        rent_term = include_rent ? sum(RT[j] for j in commodities) : 0.0
        fc_term = include_fc ? sum(JCGECore.getparam(block.params, :FC, j) for j in commodities) : 0.0
        constraint = nothing
        rent_expr = include_rent ? ESum(:j, commodities, EVar(:RT, Any[EIndex(:j)])) : EConst(0.0)
        fc_expr = include_fc ? ESum(:j, commodities, EParam(:FC, Any[EIndex(:j)])) : EConst(0.0)
        expr = EEq(
            EVar(:Xp, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:alpha, Any[EIndex(:i)]),
                    EAdd([
                        ESum(:h, factors, EMul([
                            EVar(:pf, Any[EIndex(:h)]),
                            EParam(:FF, Any[EIndex(:h)]),
                        ])),
                        ENeg(EVar(:Sp, Any[])),
                        ENeg(EVar(:Td, Any[])),
                        rent_expr,
                        fc_expr,
                    ]),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXp, i;
            info="Xp[i] == alpha[i] * (sum(pf[h]*FF[h]) - Sp - Td + sum(RT) + sum(FC)) / pq[i]",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::HouseholdDemandCDXpRegionalBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Xp = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()
    Sp = ensure_var!(ctx, model, global_var(:Sp, block.region))
    Td = ensure_var!(ctx, model, global_var(:Td, block.region))

    for i in commodities
        Xp[i] = ensure_var!(ctx, model, global_var(:Xp, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end
    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
    end

    ff_vals = Dict(h => JCGECore.getparam(block.params, :FF, h) for h in factors)
    for i in commodities
        alpha_i = JCGECore.getparam(block.params, :alpha, i)
        constraint = nothing
        expr = EEq(
            EVar(:Xp, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:alpha, Any[EIndex(:i)]),
                    EAdd([
                        ESum(:h, factors, EMul([
                            EVar(:pf, Any[EIndex(:h)]),
                            EParam(:FF, Any[EIndex(:h)]),
                        ])),
                        ENeg(EVar(:Sp, Any[EIndex(:r)])),
                        ENeg(EVar(:Td, Any[EIndex(:r)])),
                    ]),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXp, i, block.region;
            info="Xp[i] == alpha[i] * (sum(pf[h]*FF[h]) - Sp - Td) / pq[i]",
            expr=expr, index_names=(:i, :r), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::HouseholdDemandIncomeBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    Xp = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Tuple{Symbol,Symbol},Any}()
    F = Dict{Tuple{Symbol,Symbol},Any}()
    Sp = ensure_var!(ctx, model, global_var(:Sp))
    Td = ensure_var!(ctx, model, global_var(:Td))

    for i in commodities
        Xp[i] = ensure_var!(ctx, model, global_var(:Xp, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end
    for h in factors, j in activities
        pf[(h, j)] = ensure_var!(ctx, model, global_var(:pf, h, j))
        F[(h, j)] = ensure_var!(ctx, model, global_var(:F, h, j))
    end

    income = sum(pf[(h, j)] * F[(h, j)] for h in factors for j in activities)
    for i in commodities
        alpha_i = JCGECore.getparam(block.params, :alpha, i)
        constraint = nothing
        expr = EEq(
            EVar(:Xp, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:alpha, Any[EIndex(:i)]),
                    EAdd([
                        ESum(:h, factors, ESum(:j, activities, EMul([
                            EVar(:pf, Any[EIndex(:h), EIndex(:j)]),
                            EVar(:F, Any[EIndex(:h), EIndex(:j)]),
                        ]))),
                        ENeg(EVar(:Sp, Any[])),
                        ENeg(EVar(:Td, Any[])),
                    ]),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXp, i;
            info="Xp[i] == alpha[i] * (income - Sp - Td) / pq[i]",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::HouseholdDemandBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    if block.form != :cd
        error("Unsupported household demand form: $(block.form)")
    end
    if block.consumption_var == :X
        inner = HouseholdDemandCDBlock(block.name, block.commodities, block.factors, block.params)
        return JCGECore.build!(inner, ctx, spec)
    elseif block.consumption_var == :Xp
        if isempty(block.households)
            inner = HouseholdDemandCDXpBlock(block.name, block.commodities, block.factors, block.params)
            return JCGECore.build!(inner, ctx, spec)
        end
        inner = HouseholdDemandCDHHBlock(block.name, block.households, block.commodities, block.factors, block.params)
        return JCGECore.build!(inner, ctx, spec)
    else
        error("Unsupported consumption variable: $(block.consumption_var)")
    end
end

function JCGECore.build!(block::ActivityAnalysisBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    Y = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    X = Dict{Tuple{Symbol,Symbol},Any}()
    Z = Dict{Tuple{Symbol,Symbol},Any}()

    for s in activities
        Y[s] = ensure_var!(ctx, model, global_var(:Y, s))
    end
    for g in commodities
        pq[g] = ensure_var!(ctx, model, global_var(:pq, g))
    end
    for g in commodities, s in activities
        X[(g, s)] = ensure_var!(ctx, model, global_var(:X, g, s))
        Z[(g, s)] = ensure_var!(ctx, model, global_var(:Z, g, s))
    end

    for g in commodities, s in activities
        constraint = nothing
        expr = EEq(
            EVar(:X, Any[EIndex(:g), EIndex(:s)]),
            EMul([
                EParam(:a_in, Any[EIndex(:g), EIndex(:s)]),
                EVar(:Y, Any[EIndex(:s)]),
            ]),
        )
        mcp_var = mcp ? EVar(:X, Any[EIndex(:g), EIndex(:s)]) : nothing
        register_eq!(ctx, block, :eqX, g, s;
            info="X[g,s] == a_in[g,s] * Y[s]", expr=expr, index_names=(:g, :s), constraint=constraint, mcp_var=mcp_var)

        constraint = nothing
        expr = EEq(
            EVar(:Z, Any[EIndex(:g), EIndex(:s)]),
            EMul([
                EParam(:a_out, Any[EIndex(:g), EIndex(:s)]),
                EVar(:Y, Any[EIndex(:s)]),
            ]),
        )
        mcp_var = mcp ? EVar(:Z, Any[EIndex(:g), EIndex(:s)]) : nothing
        register_eq!(ctx, block, :eqZ, g, s;
            info="Z[g,s] == a_out[g,s] * Y[s]", expr=expr, index_names=(:g, :s), constraint=constraint, mcp_var=mcp_var)
    end

    for s in activities
        constraint = nothing
        lhs = ESum(:g, commodities, EMul([
            EVar(:pq, Any[EIndex(:g)]),
            EParam(:a_out, Any[EIndex(:g), EIndex(:s)]),
        ]))
        rhs = ESum(:g, commodities, EMul([
            EVar(:pq, Any[EIndex(:g)]),
            EParam(:a_in, Any[EIndex(:g), EIndex(:s)]),
        ]))
        expr = EEq(lhs, rhs)
        mcp_var = mcp ? EVar(:Y, Any[EIndex(:s)]) : nothing
        register_eq!(ctx, block, :eqZP, s;
            info="sum(pq[g]*a_out[g,s]) == sum(pq[g]*a_in[g,s])", expr=expr, index_names=(:s,), constraint=constraint, mcp_var=mcp_var)
    end

    return nothing
end

function JCGECore.build!(block::ConsumerEndowmentCDBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    consumers = isempty(block.consumers) ? spec.model.sets.institutions : block.consumers
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    Xp = Dict{Tuple{Symbol,Symbol},Any}()
    Y = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()

    for g in commodities
        pq[g] = ensure_var!(ctx, model, global_var(:pq, g))
    end
    for c in consumers
        Y[c] = ensure_var!(ctx, model, global_var(:Y, c))
    end
    for g in commodities, c in consumers
        Xp[(g, c)] = ensure_var!(ctx, model, global_var(:Xp, g, c))
    end

    for c in consumers
        constraint = nothing
        expr = EEq(
            EVar(:Y, Any[EIndex(:c)]),
            ESum(:g, commodities, EMul([
                EVar(:pq, Any[EIndex(:g)]),
                EParam(:endowment, Any[EIndex(:g), EIndex(:c)]),
            ])),
        )
        mcp_var = mcp ? EVar(:Y, Any[EIndex(:c)]) : nothing
        register_eq!(ctx, block, :eqY, c;
            info="Y[c] == sum(pq[g] * endowment[g,c])", expr=expr, index_names=(:c,), constraint=constraint, mcp_var=mcp_var)
    end

    for g in commodities, c in consumers
        constraint = nothing
        expr = EEq(
            EVar(:Xp, Any[EIndex(:g), EIndex(:c)]),
            EDiv(
                EMul([
                    EParam(:alpha, Any[EIndex(:g), EIndex(:c)]),
                    EVar(:Y, Any[EIndex(:c)]),
                ]),
                EVar(:pq, Any[EIndex(:g)]),
            ),
        )
        mcp_var = mcp ? EVar(:Xp, Any[EIndex(:g), EIndex(:c)]) : nothing
        register_eq!(ctx, block, :eqXp, g, c;
            info="Xp[g,c] == alpha[g,c] * Y[c] / pq[g]", expr=expr, index_names=(:g, :c), constraint=constraint, mcp_var=mcp_var)
    end

    return nothing
end

function JCGECore.build!(block::CommodityMarketClearingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    consumers = isempty(block.consumers) ? spec.model.sets.institutions : block.consumers
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for g in commodities
        pq = ensure_var!(ctx, model, global_var(:pq, g))
        constraint = nothing
        expr = EEq(
            EAdd([
                ESum(:s, activities, EVar(:Z, Any[EIndex(:g), EIndex(:s)])),
                ESum(:c, consumers, EParam(:endowment, Any[EIndex(:g), EIndex(:c)])),
            ]),
            EAdd([
                ESum(:s, activities, EVar(:X, Any[EIndex(:g), EIndex(:s)])),
                ESum(:c, consumers, EVar(:Xp, Any[EIndex(:g), EIndex(:c)])),
            ]),
        )
        mcp_var = mcp ? EVar(:pq, Any[EIndex(:g)]) : nothing
        register_eq!(ctx, block, :eqMC, g;
            info="sum(Z[g,s])+sum(endowment[g,c]) == sum(X[g,s])+sum(Xp[g,c])",
            expr=expr, index_names=(:g,), constraint=constraint, mcp_var=mcp_var)
    end

    return nothing
end

function JCGECore.build!(block::MarketClearingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Q = Dict{Symbol,Any}()
    Xp = Dict{Tuple{Symbol,Symbol},Any}()
    Xg = Dict{Symbol,Any}()
    Xv = Dict{Symbol,Any}()
    X = Dict{Tuple{Symbol,Symbol},Any}()
    F = Dict{Tuple{Symbol,Symbol},Any}()
    FF = Dict{Symbol,Any}()

    for i in commodities
        Q[i] = ensure_var!(ctx, model, var_name(block, :Q, i))
        Xg[i] = ensure_var!(ctx, model, var_name(block, :Xg, i))
        Xv[i] = ensure_var!(ctx, model, var_name(block, :Xv, i))
    end

    for h in factors
        FF[h] = ensure_var!(ctx, model, var_name(block, :FF, h))
    end

    for i in commodities, hh in spec.model.sets.institutions
        Xp[(i, hh)] = ensure_var!(ctx, model, var_name(block, :Xp, i, hh))
    end

    for j in commodities, i in spec.model.sets.activities
        X[(j, i)] = ensure_var!(ctx, model, var_name(block, :X, j, i))
    end

    for h in factors, i in spec.model.sets.activities
        F[(h, i)] = ensure_var!(ctx, model, var_name(block, :F, h, i))
    end

    for i in commodities
        constraint = nothing
        expr = EEq(
            EVar(:Q, Any[EIndex(:i)]),
            EAdd([
                ESum(:hh, spec.model.sets.institutions, EVar(:Xp, Any[EIndex(:i), EIndex(:hh)])),
                EVar(:Xg, Any[EIndex(:i)]),
                EVar(:Xv, Any[EIndex(:i)]),
                ESum(:j, spec.model.sets.activities, EVar(:X, Any[EIndex(:i), EIndex(:j)])),
            ]),
        )
        register_eq!(ctx, block, :eqQ, i;
            info="Q[i] == sum(Xp[i,hh]) + Xg[i] + Xv[i] + sum(X[i,j])",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    for h in factors
        constraint = nothing
        expr = EEq(
            EVar(:FF, Any[EIndex(:h)]),
            ESum(:i, spec.model.sets.activities, EVar(:F, Any[EIndex(:h), EIndex(:i)])),
        )
        register_eq!(ctx, block, :eqF, h;
            info="FF[h] == sum(F[h,i])", expr=expr, index_names=(:h,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::GoodsMarketClearingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    for i in commodities
        X = ensure_var!(ctx, model, global_var(:X, i))
        Z = ensure_var!(ctx, model, global_var(:Z, i))
        constraint = nothing
        expr = EEq(
            EVar(:X, Any[EIndex(:i)]),
            EVar(:Z, Any[EIndex(:i)]),
        )
        register_eq!(ctx, block, :eqX, i; info="X[i] == Z[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::FactorMarketClearingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    F = Dict{Tuple{Symbol,Symbol},Any}()
    for h in factors, j in activities
        F[(h, j)] = ensure_var!(ctx, model, global_var(:F, h, j))
    end

    for h in factors
        ff_h = JCGECore.getparam(block.params, :FF, h)
        constraint = nothing
        expr = EEq(
            ESum(:j, activities, EVar(:F, Any[EIndex(:h), EIndex(:j)])),
            EParam(:FF, Any[EIndex(:h)]),
        )
        register_eq!(ctx, block, :eqF, h;
            info="sum(F[h,j]) == FF[h]", expr=expr, index_names=(:h,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::CompositeMarketClearingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    Q = Dict{Symbol,Any}()
    Xp = Dict{Symbol,Any}()
    Xg = Dict{Symbol,Any}()
    Xv = Dict{Symbol,Any}()
    X = Dict{Tuple{Symbol,Symbol},Any}()

    for i in commodities
        Q[i] = ensure_var!(ctx, model, global_var(:Q, i))
        Xp[i] = ensure_var!(ctx, model, global_var(:Xp, i))
        Xg[i] = ensure_var!(ctx, model, global_var(:Xg, i))
        Xv[i] = ensure_var!(ctx, model, global_var(:Xv, i))
    end

    for i in commodities, j in activities
        X[(i, j)] = ensure_var!(ctx, model, global_var(:X, i, j))
    end

    for i in commodities
        constraint = nothing
        expr = EEq(
            EVar(:Q, Any[EIndex(:i)]),
            EAdd([
                EVar(:Xp, Any[EIndex(:i)]),
                EVar(:Xg, Any[EIndex(:i)]),
                EVar(:Xv, Any[EIndex(:i)]),
                ESum(:j, activities, EVar(:X, Any[EIndex(:i), EIndex(:j)])),
            ]),
        )
        register_eq!(ctx, block, :eqQ, i;
            info="Q[i] == Xp[i] + Xg[i] + Xv[i] + sum(X[i,j])",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::PriceLinkBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    pe = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    epsilon = ensure_var!(ctx, model, var_name(block, :epsilon))

    for i in commodities
        pe[i] = ensure_var!(ctx, model, var_name(block, :pe, i))
        pm[i] = ensure_var!(ctx, model, var_name(block, :pm, i))
    end

    for i in commodities
        pWe_i = JCGECore.getparam(block.params, :pWe, i)
        pWm_i = JCGECore.getparam(block.params, :pWm, i)
        constraint = nothing
        expr = EEq(
            EVar(:pe, Any[EIndex(:i)]),
            EMul([
                EVar(:epsilon, Any[]),
                EParam(:pWe, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqpe, i; info="pe[i] == epsilon * pWe[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:pm, Any[EIndex(:i)]),
            EMul([
                EVar(:epsilon, Any[]),
                EParam(:pWm, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqpm, i; info="pm[i] == epsilon * pWm[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::ExchangeRateLinkBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    epsilon = ensure_var!(ctx, model, global_var(:epsilon))
    pe = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    pWe = Dict{Symbol,Any}()
    pWm = Dict{Symbol,Any}()

    for i in commodities
        pe[i] = ensure_var!(ctx, model, global_var(:pe, i))
        pm[i] = ensure_var!(ctx, model, global_var(:pm, i))
        pWe[i] = ensure_var!(ctx, model, global_var(:pWe, i))
        pWm[i] = ensure_var!(ctx, model, global_var(:pWm, i))
    end

    for i in commodities
        constraint = nothing
        expr = EEq(
            EVar(:pe, Any[EIndex(:i)]),
            EMul([
                EVar(:epsilon, Any[]),
                EVar(:pWe, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqpe, i; info="pe[i] == epsilon * pWe[i]", expr=expr, index_names=(:i,), constraint=constraint)
        constraint = nothing
        expr = EEq(
            EVar(:pm, Any[EIndex(:i)]),
            EMul([
                EVar(:epsilon, Any[]),
                EVar(:pWm, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqpm, i; info="pm[i] == epsilon * pWm[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::ExchangeRateLinkRegionBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    epsilon = ensure_var!(ctx, model, global_var(:epsilon, block.region))
    pe = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    pWe = Dict{Symbol,Any}()
    pWm = Dict{Symbol,Any}()

    for i in commodities
        pe[i] = ensure_var!(ctx, model, global_var(:pe, i))
        pm[i] = ensure_var!(ctx, model, global_var(:pm, i))
        pWe[i] = ensure_var!(ctx, model, global_var(:pWe, i))
        pWm[i] = ensure_var!(ctx, model, global_var(:pWm, i))
    end

    for i in commodities
        constraint = nothing
        expr = EEq(
            EVar(:pe, Any[EIndex(:i)]),
            EMul([EVar(:epsilon, Any[EIndex(:r)]), EVar(:pWe, Any[EIndex(:i)])]),
        )
        register_eq!(ctx, block, :eqpe, i, block.region;
            info="pe[i] == epsilon[r] * pWe[i]", expr=expr, index_names=(:i, :r), constraint=constraint)
        constraint = nothing
        expr = EEq(
            EVar(:pm, Any[EIndex(:i)]),
            EMul([EVar(:epsilon, Any[EIndex(:r)]), EVar(:pWm, Any[EIndex(:i)])]),
        )
        register_eq!(ctx, block, :eqpm, i, block.region;
            info="pm[i] == epsilon[r] * pWm[i]", expr=expr, index_names=(:i, :r), constraint=constraint)
    end

    return nothing
end
function JCGECore.build!(block::PriceEqualityBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    for i in commodities
        px = ensure_var!(ctx, model, global_var(:px, i))
        pz = ensure_var!(ctx, model, global_var(:pz, i))
        constraint = nothing
        expr = EEq(EVar(:px, Any[EIndex(:i)]), EVar(:pz, Any[EIndex(:i)]))
        register_eq!(ctx, block, :eqP, i; info="px[i] == pz[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::NumeraireBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    model = ctx.model
    if model isa JuMP.Model
        if block.kind == :factor
            pf = ensure_var!(ctx, model, var_name(block, :pf, block.label))
            JuMP.fix(pf, block.value; force=true)
        elseif block.kind == :commodity
            pq = ensure_var!(ctx, model, var_name(block, :pq, block.label))
            JuMP.fix(pq, block.value; force=true)
        elseif block.kind == :exchange
            epsilon = ensure_var!(ctx, model, var_name(block, :epsilon))
            JuMP.fix(epsilon, block.value; force=true)
        else
            error("Unknown numeraire kind: $(block.kind)")
        end
    end
    register_eq!(ctx, block, :numeraire; info="numeraire fixed", constraint=nothing)
    return nothing
end

function JCGECore.build!(block::GovernmentBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Td = ensure_var!(ctx, model, global_var(:Td))
    Sg = ensure_var!(ctx, model, global_var(:Sg))
    include_rent = hasproperty(block.params, :include_rent) && getproperty(block.params, :include_rent)
    include_fc = hasproperty(block.params, :include_fc) && getproperty(block.params, :include_fc)
    Tz = Dict{Symbol,Any}()
    Tm = Dict{Symbol,Any}()
    Xg = Dict{Symbol,Any}()
    pz = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    Z = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()
    FF = Dict{Symbol,Any}()
    RT = Dict{Symbol,Any}()

    for i in commodities
        Tz[i] = ensure_var!(ctx, model, global_var(:Tz, i))
        Tm[i] = ensure_var!(ctx, model, global_var(:Tm, i))
        Xg[i] = ensure_var!(ctx, model, global_var(:Xg, i))
        pz[i] = ensure_var!(ctx, model, global_var(:pz, i))
        pm[i] = ensure_var!(ctx, model, global_var(:pm, i))
        Z[i] = ensure_var!(ctx, model, global_var(:Z, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
        if include_rent
            RT[i] = ensure_var!(ctx, model, global_var(:RT, i))
        end
    end

    use_ff_params = hasproperty(block.params, :FF)
    ff_vals = Dict{Symbol,Any}()
    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
        if use_ff_params
            ff_vals[h] = JCGECore.getparam(block.params, :FF, h)
        else
            FF[h] = ensure_var!(ctx, model, global_var(:FF, h))
        end
    end
    if !use_ff_params
        for h in factors
            ff_vals[h] = FF[h]
        end
    end

    tau_d = JCGECore.getparam(block.params, :tau_d)
    rent_term = include_rent ? sum(RT[i] for i in commodities) : 0.0
    fc_term = include_fc ? sum(JCGECore.getparam(block.params, :FC, i) for i in commodities) : 0.0
    constraint = nothing
    rent_expr = include_rent ? ESum(:i, commodities, EVar(:RT, Any[EIndex(:i)])) : EConst(0.0)
    fc_expr = include_fc ? ESum(:i, commodities, EParam(:FC, Any[EIndex(:i)])) : EConst(0.0)
    ff_expr = use_ff_params ? EParam(:FF, Any[EIndex(:h)]) : EVar(:FF, Any[EIndex(:h)])
    expr = EEq(
        EVar(:Td, Any[]),
        EMul([
            EParam(:tau_d, Any[]),
            EAdd([
                ESum(:h, factors, EMul([
                    EVar(:pf, Any[EIndex(:h)]),
                    ff_expr,
                ])),
                rent_expr,
                fc_expr,
            ]),
        ]),
    )
    register_eq!(ctx, block, :eqTd; info="Td == tau_d * (sum(pf[h] * FF[h]) + sum(RT) + sum(FC))", expr=expr, constraint=constraint)

    for i in commodities
        tau_z_i = JCGECore.getparam(block.params, :tau_z, i)
        tau_m_i = JCGECore.getparam(block.params, :tau_m, i)
        mu_i = JCGECore.getparam(block.params, :mu, i)
        constraint = nothing
        expr = EEq(
            EVar(:Tz, Any[EIndex(:i)]),
            EMul([
                EParam(:tau_z, Any[EIndex(:i)]),
                EVar(:pz, Any[EIndex(:i)]),
                EVar(:Z, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqTz, i; info="Tz[i] == tau_z[i] * pz[i] * Z[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:Tm, Any[EIndex(:i)]),
            EMul([
                EParam(:tau_m, Any[EIndex(:i)]),
                EVar(:pm, Any[EIndex(:i)]),
                EVar(:M, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqTm, i; info="Tm[i] == tau_m[i] * pm[i] * M[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:Xg, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:mu, Any[EIndex(:i)]),
                    EAdd([
                        EVar(:Td, Any[]),
                        ESum(:j, commodities, EVar(:Tz, Any[EIndex(:j)])),
                        ESum(:j, commodities, EVar(:Tm, Any[EIndex(:j)])),
                        ENeg(EVar(:Sg, Any[])),
                    ]),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXg, i; info="Xg[i] == mu[i] * (Td + sum(Tz)+sum(Tm) - Sg) / pq[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    ssg = JCGECore.getparam(block.params, :ssg)
    constraint = nothing
    expr = EEq(
        EVar(:Sg, Any[]),
        EMul([
            EParam(:ssg, Any[]),
            EAdd([
                EVar(:Td, Any[]),
                ESum(:i, commodities, EVar(:Tz, Any[EIndex(:i)])),
                ESum(:i, commodities, EVar(:Tm, Any[EIndex(:i)])),
            ]),
        ]),
    )
    register_eq!(ctx, block, :eqSg; info="Sg == ssg * (Td + sum(Tz) + sum(Tm))", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::GovernmentRegionalBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Td = ensure_var!(ctx, model, global_var(:Td, block.region))
    Sg = ensure_var!(ctx, model, global_var(:Sg, block.region))
    Tz = Dict{Symbol,Any}()
    Tm = Dict{Symbol,Any}()
    Xg = Dict{Symbol,Any}()
    pz = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    Z = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pf = Dict{Symbol,Any}()
    ff_vals = Dict{Symbol,Any}()

    for i in commodities
        Tz[i] = ensure_var!(ctx, model, global_var(:Tz, i))
        Tm[i] = ensure_var!(ctx, model, global_var(:Tm, i))
        Xg[i] = ensure_var!(ctx, model, global_var(:Xg, i))
        pz[i] = ensure_var!(ctx, model, global_var(:pz, i))
        pm[i] = ensure_var!(ctx, model, global_var(:pm, i))
        Z[i] = ensure_var!(ctx, model, global_var(:Z, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end

    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
        ff_vals[h] = JCGECore.getparam(block.params, :FF, h)
    end

    tau_d = JCGECore.getparam(block.params, :tau_d)
    constraint = nothing
    expr = EEq(
        EVar(:Td, Any[block.region]),
        EMul([
            EParam(:tau_d, Any[]),
            ESum(:h, factors, EMul([
                EVar(:pf, Any[EIndex(:h)]),
                EParam(:FF, Any[EIndex(:h)]),
            ])),
        ]),
    )
    register_eq!(ctx, block, :eqTd, block.region; info="Td[r] == tau_d[r] * sum(pf[h,r] * FF[h,r])", expr=expr, constraint=constraint)

    for i in commodities
        tau_z_i = JCGECore.getparam(block.params, :tau_z, i)
        tau_m_i = JCGECore.getparam(block.params, :tau_m, i)
        mu_i = JCGECore.getparam(block.params, :mu, i)
        constraint = nothing
        expr = EEq(
            EVar(:Tz, Any[EIndex(:i)]),
            EMul([
                EParam(:tau_z, Any[EIndex(:i)]),
                EVar(:pz, Any[EIndex(:i)]),
                EVar(:Z, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqTz, i; info="Tz[i] == tau_z[i] * pz[i] * Z[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:Tm, Any[EIndex(:i)]),
            EMul([
                EParam(:tau_m, Any[EIndex(:i)]),
                EVar(:pm, Any[EIndex(:i)]),
                EVar(:M, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqTm, i; info="Tm[i] == tau_m[i] * pm[i] * M[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:Xg, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:mu, Any[EIndex(:i)]),
                    EAdd([
                        EVar(:Td, Any[block.region]),
                        ESum(:j, commodities, EVar(:Tz, Any[EIndex(:j)])),
                        ESum(:j, commodities, EVar(:Tm, Any[EIndex(:j)])),
                        ENeg(EVar(:Sg, Any[block.region])),
                    ]),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXg, i; info="Xg[i] == mu[i] * (Td + sum(Tz)+sum(Tm) - Sg) / pq[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    ssg = JCGECore.getparam(block.params, :ssg)
    constraint = nothing
    expr = EEq(
        EVar(:Sg, Any[block.region]),
        EMul([
            EParam(:ssg, Any[]),
            EAdd([
                EVar(:Td, Any[block.region]),
                ESum(:i, commodities, EVar(:Tz, Any[EIndex(:i)])),
                ESum(:i, commodities, EVar(:Tm, Any[EIndex(:i)])),
            ]),
        ]),
    )
    register_eq!(ctx, block, :eqSg, block.region; info="Sg[r] == ssg[r] * (Td + sum(Tz) + sum(Tm))", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::GovernmentBudgetBalanceBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    Td = ensure_var!(ctx, model, global_var(:Td))
    Tz = Dict{Symbol,Any}()
    Tm = Dict{Symbol,Any}()
    Xg = Dict{Symbol,Any}()
    pz = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    Z = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()

    for i in commodities
        Tz[i] = ensure_var!(ctx, model, global_var(:Tz, i))
        Tm[i] = ensure_var!(ctx, model, global_var(:Tm, i))
        Xg[i] = ensure_var!(ctx, model, global_var(:Xg, i))
        pz[i] = ensure_var!(ctx, model, global_var(:pz, i))
        pm[i] = ensure_var!(ctx, model, global_var(:pm, i))
        Z[i] = ensure_var!(ctx, model, global_var(:Z, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end

    for i in commodities
        tau_z_i = JCGECore.getparam(block.params, :tauz, i)
        tau_m_i = JCGECore.getparam(block.params, :taum, i)
        constraint = nothing
        expr = EEq(
            EVar(:Tz, Any[EIndex(:i)]),
            EMul([
                EParam(:tauz, Any[EIndex(:i)]),
                EVar(:pz, Any[EIndex(:i)]),
                EVar(:Z, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqTz, i; info="Tz[i] == tauz[i] * pz[i] * Z[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EVar(:Tm, Any[EIndex(:i)]),
            EMul([
                EParam(:taum, Any[EIndex(:i)]),
                EVar(:pm, Any[EIndex(:i)]),
                EVar(:M, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqTm, i; info="Tm[i] == taum[i] * pm[i] * M[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    constraint = nothing
    expr = EEq(
        EVar(:Td, Any[]),
        EAdd([
            ESum(:i, commodities, EMul([
                EVar(:pq, Any[EIndex(:i)]),
                EVar(:Xg, Any[EIndex(:i)]),
            ])),
            ENeg(ESum(:i, commodities, EVar(:Tz, Any[EIndex(:i)]))),
            ENeg(ESum(:i, commodities, EVar(:Tm, Any[EIndex(:i)]))),
        ]),
    )
    register_eq!(ctx, block, :eqTd; info="Td == sum(pq[i]*Xg[i]) - sum(Tz[i] + Tm[i])", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::PrivateSavingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Sp = ensure_var!(ctx, model, global_var(:Sp))
    pf = Dict{Symbol,Any}()
    RT = Dict{Symbol,Any}()
    include_rent = hasproperty(block.params, :include_rent) && getproperty(block.params, :include_rent)
    include_fc = hasproperty(block.params, :include_fc) && getproperty(block.params, :include_fc)
    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
    end

    ssp = JCGECore.getparam(block.params, :ssp)
    ff_vals = Dict(h => JCGECore.getparam(block.params, :FF, h) for h in factors)
    if include_rent
        for i in spec.model.sets.commodities
            RT[i] = ensure_var!(ctx, model, global_var(:RT, i))
        end
    end
    rent_term = include_rent ? sum(RT[i] for i in spec.model.sets.commodities) : 0.0
    fc_term = include_fc ? sum(JCGECore.getparam(block.params, :FC, i) for i in spec.model.sets.commodities) : 0.0
    constraint = nothing
    rent_expr = include_rent ? ESum(:i, spec.model.sets.commodities, EVar(:RT, Any[EIndex(:i)])) : EConst(0.0)
    fc_expr = include_fc ? ESum(:i, spec.model.sets.commodities, EParam(:FC, Any[EIndex(:i)])) : EConst(0.0)
    expr = EEq(
        EVar(:Sp, Any[]),
        EMul([
            EParam(:ssp, Any[]),
            EAdd([
                ESum(:h, factors, EMul([
                    EVar(:pf, Any[EIndex(:h)]),
                    EParam(:FF, Any[EIndex(:h)]),
                ])),
                rent_expr,
                fc_expr,
            ]),
        ]),
    )
    register_eq!(ctx, block, :eqSp; info="Sp == ssp * (sum(pf[h] * FF[h]) + sum(RT) + sum(FC))", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::PrivateSavingRegionalBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    model = ctx.model

    Sp = ensure_var!(ctx, model, global_var(:Sp, block.region))
    pf = Dict{Symbol,Any}()
    for h in factors
        pf[h] = ensure_var!(ctx, model, global_var(:pf, h))
    end

    ssp = JCGECore.getparam(block.params, :ssp)
    ff_vals = Dict(h => JCGECore.getparam(block.params, :FF, h) for h in factors)
    constraint = nothing
    expr = EEq(
        EVar(:Sp, Any[block.region]),
        EMul([
            EParam(:ssp, Any[]),
            ESum(:h, factors, EMul([
                EVar(:pf, Any[EIndex(:h)]),
                EParam(:FF, Any[EIndex(:h)]),
            ])),
        ]),
    )
    register_eq!(ctx, block, :eqSp, block.region; info="Sp[r] == ssp[r] * sum(pf[h,r] * FF[h,r])", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::PrivateSavingIncomeBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    Sp = ensure_var!(ctx, model, global_var(:Sp))
    Td = ensure_var!(ctx, model, global_var(:Td))
    pf = Dict{Tuple{Symbol,Symbol},Any}()
    F = Dict{Tuple{Symbol,Symbol},Any}()

    for h in factors, j in activities
        pf[(h, j)] = ensure_var!(ctx, model, global_var(:pf, h, j))
        F[(h, j)] = ensure_var!(ctx, model, global_var(:F, h, j))
    end

    ssp = JCGECore.getparam(block.params, :ssp)
    income = sum(pf[(h, j)] * F[(h, j)] for h in factors for j in activities)
    constraint = nothing
    expr = EEq(
        EVar(:Sp, Any[]),
        EMul([
            EParam(:ssp, Any[]),
            EAdd([
                ESum(:h, factors, ESum(:j, activities, EMul([
                    EVar(:pf, Any[EIndex(:h), EIndex(:j)]),
                    EVar(:F, Any[EIndex(:h), EIndex(:j)]),
                ]))),
                ENeg(EVar(:Td, Any[])),
            ]),
        ]),
    )
    register_eq!(ctx, block, :eqSp; info="Sp == ssp * (sum(pf[h,j]*F[h,j]) - Td)", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::InvestmentBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    Sp = ensure_var!(ctx, model, global_var(:Sp))
    Sg = ensure_var!(ctx, model, global_var(:Sg))
    Xv = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    epsilon = ensure_var!(ctx, model, global_var(:epsilon))

    for i in commodities
        Xv[i] = ensure_var!(ctx, model, global_var(:Xv, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end

    Sf = JCGECore.getparam(block.params, :Sf)
    for i in commodities
        lambda_i = JCGECore.getparam(block.params, :lambda, i)
        constraint = nothing
        expr = EEq(
            EVar(:Xv, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:lambda, Any[EIndex(:i)]),
                    EAdd([
                        EVar(:Sp, Any[]),
                        EVar(:Sg, Any[]),
                        EMul([
                            EVar(:epsilon, Any[]),
                            EParam(:Sf, Any[]),
                        ]),
                    ]),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXv, i; info="Xv[i] == lambda[i] * (Sp + Sg + epsilon*Sf) / pq[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::InvestmentRegionalBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    Sp = ensure_var!(ctx, model, global_var(:Sp, block.region))
    Sg = ensure_var!(ctx, model, global_var(:Sg, block.region))
    Xv = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    epsilon = ensure_var!(ctx, model, global_var(:epsilon, block.region))

    for i in commodities
        Xv[i] = ensure_var!(ctx, model, global_var(:Xv, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end

    Sf = JCGECore.getparam(block.params, :Sf)
    for i in commodities
        lambda_i = JCGECore.getparam(block.params, :lambda, i)
        constraint = nothing
        expr = EEq(
            EVar(:Xv, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:lambda, Any[EIndex(:i)]),
                    EAdd([
                        EVar(:Sp, Any[block.region]),
                        EVar(:Sg, Any[block.region]),
                        EMul([
                            EVar(:epsilon, Any[block.region]),
                            EParam(:Sf, Any[]),
                        ]),
                    ]),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXv, i; info="Xv[i] == lambda[i] * (Sp + Sg + epsilon*Sf) / pq[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::ArmingtonCESBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    Q = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    D = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    pd = Dict{Symbol,Any}()

    for i in commodities
        Q[i] = ensure_var!(ctx, model, global_var(:Q, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
        D[i] = ensure_var!(ctx, model, global_var(:D, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
        pm[i] = ensure_var!(ctx, model, global_var(:pm, i))
        pd[i] = ensure_var!(ctx, model, global_var(:pd, i))
    end

    for i in commodities
        gamma_i = JCGECore.getparam(block.params, :gamma, i)
        delta_m_i = JCGECore.getparam(block.params, :delta_m, i)
        delta_d_i = JCGECore.getparam(block.params, :delta_d, i)
        eta_i = JCGECore.getparam(block.params, :eta, i)
        tau_m_i = JCGECore.getparam(block.params, :tau_m, i)
        pd_scale_i = hasproperty(block.params, :pd_scale) ? JCGECore.getparam(block.params, :pd_scale, i) : 1.0
        include_chi = hasproperty(block.params, :include_chi) && getproperty(block.params, :include_chi)
        chi_i = include_chi ? ensure_var!(ctx, model, global_var(:chi, i)) : 0.0

        constraint = nothing
        expr = EEq(
            EVar(:Q, Any[EIndex(:i)]),
            EMul([
                EParam(:gamma, Any[EIndex(:i)]),
                EPow(
                    EAdd([
                        EMul([
                            EParam(:delta_m, Any[EIndex(:i)]),
                            EPow(EVar(:M, Any[EIndex(:i)]), EParam(:eta, Any[EIndex(:i)])),
                        ]),
                        EMul([
                            EParam(:delta_d, Any[EIndex(:i)]),
                            EPow(EVar(:D, Any[EIndex(:i)]), EParam(:eta, Any[EIndex(:i)])),
                        ]),
                    ]),
                    EDiv(EConst(1.0), EParam(:eta, Any[EIndex(:i)])),
                ),
            ]),
        )
        register_eq!(ctx, block, :eqQ, i;
            info="Q[i] == gamma[i]*(delta_m*M^eta + delta_d*D^eta)^(1/eta)",
            expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        chi_expr = include_chi ? EVar(:chi, Any[EIndex(:i)]) : EConst(0.0)
        ratio_m = EDiv(
            EMul([
                EPow(EParam(:gamma, Any[EIndex(:i)]), EParam(:eta, Any[EIndex(:i)])),
                EParam(:delta_m, Any[EIndex(:i)]),
                EVar(:pq, Any[EIndex(:i)]),
            ]),
            EMul([
                EAdd([
                    EConst(1.0),
                    chi_expr,
                    EParam(:tau_m, Any[EIndex(:i)]),
                ]),
                EVar(:pm, Any[EIndex(:i)]),
            ]),
        )
        expr = EEq(
            EVar(:M, Any[EIndex(:i)]),
            EMul([
                EPow(
                    ratio_m,
                    EDiv(EConst(1.0), EAdd([EConst(1.0), ENeg(EParam(:eta, Any[EIndex(:i)]))])),
                ),
                EVar(:Q, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqM, i; info="M[i] == (...) * Q[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        pd_scale_expr = hasproperty(block.params, :pd_scale) ? EParam(:pd_scale, Any[EIndex(:i)]) : EConst(1.0)
        ratio_d = EDiv(
            EMul([
                EPow(EParam(:gamma, Any[EIndex(:i)]), EParam(:eta, Any[EIndex(:i)])),
                EParam(:delta_d, Any[EIndex(:i)]),
                EVar(:pq, Any[EIndex(:i)]),
            ]),
            EMul([
                pd_scale_expr,
                EVar(:pd, Any[EIndex(:i)]),
            ]),
        )
        expr = EEq(
            EVar(:D, Any[EIndex(:i)]),
            EMul([
                EPow(
                    ratio_d,
                    EDiv(EConst(1.0), EAdd([EConst(1.0), ENeg(EParam(:eta, Any[EIndex(:i)]))])),
                ),
                EVar(:Q, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqD, i; info="D[i] == (...) * Q[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::TransformationCETBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    Z = Dict{Symbol,Any}()
    E = Dict{Symbol,Any}()
    D = Dict{Symbol,Any}()
    pz = Dict{Symbol,Any}()
    pe = Dict{Symbol,Any}()
    pd = Dict{Symbol,Any}()

    for i in commodities
        Z[i] = ensure_var!(ctx, model, global_var(:Z, i))
        E[i] = ensure_var!(ctx, model, global_var(:E, i))
        D[i] = ensure_var!(ctx, model, global_var(:D, i))
        pz[i] = ensure_var!(ctx, model, global_var(:pz, i))
        pe[i] = ensure_var!(ctx, model, global_var(:pe, i))
        pd[i] = ensure_var!(ctx, model, global_var(:pd, i))
    end

    for i in commodities
        theta_i = JCGECore.getparam(block.params, :theta, i)
        xie_i = JCGECore.getparam(block.params, :xie, i)
        xid_i = JCGECore.getparam(block.params, :xid, i)
        phi_i = JCGECore.getparam(block.params, :phi, i)
        tau_z_i = JCGECore.getparam(block.params, :tau_z, i)

        constraint = nothing
        expr = EEq(
            EVar(:Z, Any[EIndex(:i)]),
            EMul([
                EParam(:theta, Any[EIndex(:i)]),
                EPow(
                    EAdd([
                        EMul([
                            EParam(:xie, Any[EIndex(:i)]),
                            EPow(EVar(:E, Any[EIndex(:i)]), EParam(:phi, Any[EIndex(:i)])),
                        ]),
                        EMul([
                            EParam(:xid, Any[EIndex(:i)]),
                            EPow(EVar(:D, Any[EIndex(:i)]), EParam(:phi, Any[EIndex(:i)])),
                        ]),
                    ]),
                    EDiv(EConst(1.0), EParam(:phi, Any[EIndex(:i)])),
                ),
            ]),
        )
        register_eq!(ctx, block, :eqZ, i;
            info="Z[i] == theta[i]*(xie*E^phi + xid*D^phi)^(1/phi)",
            expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        ratio_e = EDiv(
            EMul([
                EPow(EParam(:theta, Any[EIndex(:i)]), EParam(:phi, Any[EIndex(:i)])),
                EParam(:xie, Any[EIndex(:i)]),
                EAdd([EConst(1.0), EParam(:tau_z, Any[EIndex(:i)])]),
                EVar(:pz, Any[EIndex(:i)]),
            ]),
            EVar(:pe, Any[EIndex(:i)]),
        )
        expr = EEq(
            EVar(:E, Any[EIndex(:i)]),
            EMul([
                EPow(
                    ratio_e,
                    EDiv(EConst(1.0), EAdd([EConst(1.0), ENeg(EParam(:phi, Any[EIndex(:i)]))])),
                ),
                EVar(:Z, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqE, i; info="E[i] == (...) * Z[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        ratio_d = EDiv(
            EMul([
                EPow(EParam(:theta, Any[EIndex(:i)]), EParam(:phi, Any[EIndex(:i)])),
                EParam(:xid, Any[EIndex(:i)]),
                EAdd([EConst(1.0), EParam(:tau_z, Any[EIndex(:i)])]),
                EVar(:pz, Any[EIndex(:i)]),
            ]),
            EVar(:pd, Any[EIndex(:i)]),
        )
        expr = EEq(
            EVar(:D, Any[EIndex(:i)]),
            EMul([
                EPow(
                    ratio_d,
                    EDiv(EConst(1.0), EAdd([EConst(1.0), ENeg(EParam(:phi, Any[EIndex(:i)]))])),
                ),
                EVar(:Z, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqDs, i; info="D[i] == (...) * Z[i]", expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::MonopolyRentBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    RT = Dict{Symbol,Any}()
    pd = Dict{Symbol,Any}()
    D = Dict{Symbol,Any}()

    for i in commodities
        RT[i] = ensure_var!(ctx, model, global_var(:RT, i))
        pd[i] = ensure_var!(ctx, model, global_var(:pd, i))
        D[i] = ensure_var!(ctx, model, global_var(:D, i))
    end

    for i in commodities
        eta_i = JCGECore.getparam(block.params, :eta, i)
        constraint = nothing
        expr = EEq(
            EVar(:RT, Any[EIndex(:i)]),
            EMul([
                EDiv(
                    EAdd([EConst(1.0), ENeg(EParam(:eta, Any[EIndex(:i)]))]),
                    EParam(:eta, Any[EIndex(:i)]),
                ),
                EVar(:pd, Any[EIndex(:i)]),
                EVar(:D, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqRT, i;
            info="RT[i] == (1-eta[i])/eta[i] * pd[i] * D[i]",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::ImportQuotaBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    chi = Dict{Symbol,Any}()
    RT = Dict{Symbol,Any}()
    pm = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()

    for i in commodities
        chi[i] = ensure_var!(ctx, model, global_var(:chi, i))
        RT[i] = ensure_var!(ctx, model, global_var(:RT, i))
        pm[i] = ensure_var!(ctx, model, global_var(:pm, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
    end

    for i in commodities
        Mquota_i = JCGECore.getparam(block.params, :Mquota, i)
        constraint = nothing
        expr = EEq(
            EVar(:RT, Any[EIndex(:i)]),
            EMul([
                EVar(:chi, Any[EIndex(:i)]),
                EVar(:pm, Any[EIndex(:i)]),
                EVar(:M, Any[EIndex(:i)]),
            ]),
        )
        register_eq!(ctx, block, :eqRT, i; info="RT[i] == chi[i] * pm[i] * M[i]", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        expr = EEq(
            EMul([
                EVar(:chi, Any[EIndex(:i)]),
                EAdd([
                    EParam(:Mquota, Any[EIndex(:i)]),
                    ENeg(EVar(:M, Any[EIndex(:i)])),
                ]),
            ]),
            EConst(0.0),
        )
        register_eq!(ctx, block, :eqchi1, i; info="chi[i] * (Mquota[i] - M[i]) == 0", expr=expr, index_names=(:i,), constraint=constraint)

        constraint = nothing
        register_eq!(ctx, block, :eqchi2, i; info="Mquota[i] - M[i] >= 0", constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::MobileFactorMarketBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    factors = isempty(block.factors) ? spec.model.sets.factors : block.factors
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    F = Dict{Tuple{Symbol,Symbol},Any}()
    pf = Dict{Tuple{Symbol,Symbol},Any}()
    FF = Dict{Symbol,Any}()

    for h in factors
        FF[h] = ensure_var!(ctx, model, global_var(:FF, h))
        for j in activities
            F[(h, j)] = ensure_var!(ctx, model, global_var(:F, h, j))
            pf[(h, j)] = ensure_var!(ctx, model, global_var(:pf, h, j))
        end
    end

    for h in factors
        constraint = nothing
        expr = EEq(
            ESum(:j, activities, EVar(:F, Any[EIndex(:h), EIndex(:j)])),
            EVar(:FF, Any[EIndex(:h)]),
        )
        register_eq!(ctx, block, :eqpf1, h;
            info="sum(F[h,j]) == FF[h]", expr=expr, index_names=(:h,), constraint=constraint)

        if length(activities) > 1
            ref = activities[1]
            for j in activities[2:end]
                constraint = nothing
                expr = EEq(
                    EVar(:pf, Any[EIndex(:h), EIndex(:j)]),
                    EVar(:pf, Any[EIndex(:h), ref]),
                )
                register_eq!(ctx, block, :eqpf2, h, j;
                    info="pf[h,j] == pf[h,ref]", expr=expr, index_names=(:h, :j), constraint=constraint)
            end
        end
    end

    return nothing
end

function JCGECore.build!(block::CapitalStockReturnBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    F = Dict{Tuple{Symbol,Symbol},Any}()
    KK = Dict{Symbol,Any}()
    for j in activities
        F[(block.factor, j)] = ensure_var!(ctx, model, global_var(:F, block.factor, j))
        KK[j] = ensure_var!(ctx, model, global_var(:KK, j))
    end

    ror = JCGECore.getparam(block.params, :ror)
    for j in activities
        constraint = nothing
        expr = EEq(
            EVar(:F, Any[block.factor, EIndex(:j)]),
            EMul([
                EParam(:ror, Any[]),
                EVar(:KK, Any[EIndex(:j)]),
            ]),
        )
        register_eq!(ctx, block, :eqpf3, j;
            info="F[factor,j] == ror * KK[j]", expr=expr, index_names=(:j,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::CompositeInvestmentBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    Xv = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    II = Dict{Symbol,Any}()
    pk = ensure_var!(ctx, model, global_var(:pk))
    III = ensure_var!(ctx, model, global_var(:III))

    for i in commodities
        Xv[i] = ensure_var!(ctx, model, global_var(:Xv, i))
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end
    for j in activities
        II[j] = ensure_var!(ctx, model, global_var(:II, j))
    end

    sum_ii = sum(II[j] for j in activities)
    for i in commodities
        lambda_i = JCGECore.getparam(block.params, :lambda, i)
        constraint = nothing
        expr = EEq(
            EVar(:Xv, Any[EIndex(:i)]),
            EDiv(
                EMul([
                    EParam(:lambda, Any[EIndex(:i)]),
                    EVar(:pk, Any[]),
                    ESum(:j, activities, EVar(:II, Any[EIndex(:j)])),
                ]),
                EVar(:pq, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqXv, i;
            info="Xv[i] == lambda[i] * pk * sum(II) / pq[i]",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    iota = JCGECore.getparam(block.params, :iota)
        expr = EEq(
            EVar(:III, Any[]),
            EMul([
                EParam(:iota, Any[]),
                EProd(:i, commodities, EPow(
                    EVar(:Xv, Any[EIndex(:i)]),
                    EParam(:lambda, Any[EIndex(:i)]),
                )),
            ]),
        )
        register_eq!(ctx, block, :eqIII; info="III == iota * prod(Xv[i]^lambda[i])", expr=expr, constraint=nothing)

    constraint = nothing
    expr = EEq(
        ESum(:j, activities, EVar(:II, Any[EIndex(:j)])),
        EVar(:III, Any[]),
    )
    register_eq!(ctx, block, :eqpk; info="sum(II) == III", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::InvestmentAllocationBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    pf = Dict{Tuple{Symbol,Symbol},Any}()
    F = Dict{Tuple{Symbol,Symbol},Any}()
    II = Dict{Symbol,Any}()
    pk = ensure_var!(ctx, model, global_var(:pk))
    Sp = ensure_var!(ctx, model, global_var(:Sp))
    Sf = ensure_var!(ctx, model, global_var(:Sf))
    epsilon = ensure_var!(ctx, model, global_var(:epsilon))

    for j in activities
        pf[(block.factor, j)] = ensure_var!(ctx, model, global_var(:pf, block.factor, j))
        F[(block.factor, j)] = ensure_var!(ctx, model, global_var(:F, block.factor, j))
        II[j] = ensure_var!(ctx, model, global_var(:II, j))
    end

    zeta = JCGECore.getparam(block.params, :zeta)
    denom = sum(pf[(block.factor, j)] ^ zeta * F[(block.factor, j)] for j in activities)
    for j in activities
        constraint = nothing
        denom_expr = ESum(:k, activities, EMul([
            EPow(EVar(:pf, Any[block.factor, EIndex(:k)]), EParam(:zeta, Any[])),
            EVar(:F, Any[block.factor, EIndex(:k)]),
        ]))
        expr = EEq(
            EMul([
                EVar(:pk, Any[]),
                EVar(:II, Any[EIndex(:j)]),
            ]),
            EMul([
                EDiv(
                    EMul([
                        EPow(EVar(:pf, Any[block.factor, EIndex(:j)]), EParam(:zeta, Any[])),
                        EVar(:F, Any[block.factor, EIndex(:j)]),
                    ]),
                    denom_expr,
                ),
                EAdd([
                    EVar(:Sp, Any[]),
                    EMul([
                        EVar(:epsilon, Any[]),
                        EVar(:Sf, Any[]),
                    ]),
                ]),
            ]),
        )
        register_eq!(ctx, block, :eqII, j;
            info="pk*II[j] == pf^zeta*F/denom*(Sp+epsilon*Sf)",
            expr=expr, index_names=(:j,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::CompositeConsumptionBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    CC = ensure_var!(ctx, model, global_var(:CC))
    Xp = Dict{Symbol,Any}()
    for i in commodities
        Xp[i] = ensure_var!(ctx, model, global_var(:Xp, i))
    end

    expr = EEq(
        EVar(:CC, Any[]),
        EMul([
            EParam(:a, Any[]),
            EProd(:i, commodities, EPow(
                EVar(:Xp, Any[EIndex(:i)]),
                EParam(:alpha, Any[EIndex(:i)]),
            )),
        ]),
    )
    register_eq!(ctx, block, :eqCC; info="CC == a * prod(Xp[i]^alpha[i])", expr=expr, constraint=nothing)
    register_eq!(ctx, block, :objective; info="maximize CC",
        objective_expr=EVar(:CC, Any[]), objective_sense=:Max, constraint=nothing)
    return nothing
end

function JCGECore.build!(block::PriceLevelBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    PRICE = ensure_var!(ctx, model, global_var(:PRICE))
    pq = Dict{Symbol,Any}()
    for i in commodities
        pq[i] = ensure_var!(ctx, model, global_var(:pq, i))
    end

    weights = Dict(i => JCGECore.getparam(block.params, :w, i) for i in commodities)
    constraint = nothing
    expr = EEq(
        EVar(:PRICE, Any[]),
        ESum(:i, commodities, EMul([
            EVar(:pq, Any[EIndex(:i)]),
            EParam(:w, Any[EIndex(:i)]),
        ])),
    )
    register_eq!(ctx, block, :eqPRICE; info="PRICE == sum(pq[i]*w[i])", expr=expr, constraint=constraint)
    return nothing
end

function JCGECore.build!(block::PriceIndexBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    pindex = ensure_var!(ctx, model, global_var(:pindex))
    p = Dict{Symbol,Any}()
    for i in commodities
        p[i] = ensure_var!(ctx, model, global_var(:p, i))
    end

    weights = Dict(i => JCGECore.getparam(block.params, :pwts, i) for i in commodities)
    constraint = nothing
    mcp_var = mcp ? EVar(:pindex, Any[]) : nothing
    eq_expr = EEq(
        EVar(:pindex, Any[]),
        ESum(:i, commodities, EMul([
            EVar(:p, Any[EIndex(:i)]),
            EParam(:pwts, Any[EIndex(:i)]),
        ])),
    )
    register_eq!(ctx, block, :pindexdef; info="pindex == sum(p[i]*pwts[i])",
        expr=eq_expr, mcp_var=mcp_var, constraint=constraint)
    return nothing
end

function JCGECore.build!(block::ClosureBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    model = ctx.model

    if hasproperty(block.params, :fixed)
        fixed = block.params.fixed
        for (name, value) in fixed
            var = ensure_var!(ctx, model, global_var(Symbol(name)))
            if model isa JuMP.Model
                JuMP.fix(var, value; force=true)
            end
            expr = EEq(EVar(Symbol(name), Any[]), EConst(value))
            register_eq!(ctx, block, :fix, name; info="fix $(name) == $(value)", expr=expr, constraint=nothing)
        end
    end

    if hasproperty(block.params, :equalities)
        eqs = block.params.equalities
        for (lhs, rhs) in eqs
            var_lhs = ensure_var!(ctx, model, global_var(Symbol(lhs)))
            var_rhs = ensure_var!(ctx, model, global_var(Symbol(rhs)))
            constraint = nothing
            expr = EEq(EVar(Symbol(lhs), Any[]), EVar(Symbol(rhs), Any[]))
            register_eq!(ctx, block, :eq, lhs, rhs; info="fix $(lhs) == $(rhs)", expr=expr, constraint=constraint)
        end
    end

    return nothing
end

function JCGECore.build!(block::UtilityCDHHBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    households = isempty(block.households) ? spec.model.sets.institutions : block.households
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    Xp = Dict{Tuple{Symbol,Symbol},Any}()
    for i in commodities, hh in households
        Xp[(i, hh)] = ensure_var!(ctx, model, global_var(:Xp, i, hh))
    end

    objective_expr = ESum(:hh, households, EProd(:i, commodities, EPow(
        EVar(:Xp, Any[EIndex(:i), EIndex(:hh)]),
        EParam(:alpha, Any[EIndex(:i), EIndex(:hh)]),
    )))
    register_eq!(ctx, block, :objective; info="maximize household utility",
        objective_expr=objective_expr, objective_sense=:Max, constraint=nothing)
    return nothing
end

function JCGECore.build!(block::UtilityCDRegionalBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    model = ctx.model
    goods_by_region = block.goods_by_region
    regions = collect(keys(goods_by_region))
    UU = Dict{Symbol,Any}()

    for r in regions
        UU[r] = ensure_var!(ctx, model, global_var(:UU, r))
        goods = goods_by_region[r]
        Xp = Dict{Symbol,Any}()
        for i in goods
            Xp[i] = ensure_var!(ctx, model, global_var(:Xp, i))
        end
        expr = EEq(
            EVar(:UU, Any[EIndex(:r)]),
            EProd(:i, goods, EPow(
                EVar(:Xp, Any[EIndex(:i)]),
                EParam(:alpha, Any[EIndex(:i)]),
            )),
        )
        register_eq!(ctx, block, :eqUU, r;
            info="UU[r] == prod(Xp[i]^alpha[i])", expr=expr, index_names=(:r,), constraint=nothing)
    end

    objective_expr = ESum(:r, regions, EVar(:UU, Any[EIndex(:r)]))
    register_eq!(ctx, block, :objective; info="maximize social welfare",
        objective_expr=objective_expr, objective_sense=:Max, constraint=nothing)
    return nothing
end

function JCGECore.build!(block::UtilityCDBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    X = Dict{Symbol,Any}()
    for i in commodities
        X[i] = ensure_var!(ctx, model, global_var(:X, i))
    end

    objective_expr = EProd(:i, commodities, EPow(
        EVar(:X, Any[EIndex(:i)]),
        EParam(:alpha, Any[EIndex(:i)]),
    ))
    register_eq!(ctx, block, :objective; info="maximize Cobb-Douglas utility",
        objective_expr=objective_expr, objective_sense=:Max, constraint=nothing)
    return nothing
end

function JCGECore.build!(block::UtilityCDXpBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    Xp = Dict{Symbol,Any}()
    for i in commodities
        Xp[i] = ensure_var!(ctx, model, global_var(:Xp, i))
    end

    objective_expr = EProd(:i, commodities, EPow(
        EVar(:Xp, Any[EIndex(:i)]),
        EParam(:alpha, Any[EIndex(:i)]),
    ))
    register_eq!(ctx, block, :objective; info="maximize Cobb-Douglas utility over Xp",
        objective_expr=objective_expr, objective_sense=:Max, constraint=nothing)
    return nothing
end

function JCGECore.build!(block::UtilityBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    if block.form != :cd
        error("Unsupported utility form: $(block.form)")
    end
    if block.consumption_var == :X
        inner = UtilityCDBlock(block.name, block.commodities, block.params)
        return JCGECore.build!(inner, ctx, spec)
    elseif block.consumption_var == :Xp
        if isempty(block.households)
            inner = UtilityCDXpBlock(block.name, block.commodities, block.params)
            return JCGECore.build!(inner, ctx, spec)
        end
        inner = UtilityCDHHBlock(block.name, block.households, block.commodities, block.params)
        return JCGECore.build!(inner, ctx, spec)
    else
        error("Unsupported consumption variable: $(block.consumption_var)")
    end
end

function JCGECore.build!(block::ExternalBalanceBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    E = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    for i in commodities
        E[i] = ensure_var!(ctx, model, global_var(:E, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
    end

    Sf = JCGECore.getparam(block.params, :Sf)
    pWe_vals = Dict(i => JCGECore.getparam(block.params, :pWe, i) for i in commodities)
    pWm_vals = Dict(i => JCGECore.getparam(block.params, :pWm, i) for i in commodities)
    constraint = nothing
    expr = EEq(
        EAdd([
            ESum(:i, commodities, EMul([
                EParam(:pWe, Any[EIndex(:i)]),
                EVar(:E, Any[EIndex(:i)]),
            ])),
            EParam(:Sf, Any[]),
        ]),
        ESum(:i, commodities, EMul([
            EParam(:pWm, Any[EIndex(:i)]),
            EVar(:M, Any[EIndex(:i)]),
        ])),
    )
    register_eq!(ctx, block, :eqBOP; info="sum(pWe[i]*E[i]) + Sf == sum(pWm[i]*M[i])", expr=expr, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::ExternalBalanceVarPriceBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    E = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    pWe = Dict{Symbol,Any}()
    pWm = Dict{Symbol,Any}()
    for i in commodities
        E[i] = ensure_var!(ctx, model, global_var(:E, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
        pWe[i] = ensure_var!(ctx, model, global_var(:pWe, i))
        pWm[i] = ensure_var!(ctx, model, global_var(:pWm, i))
    end

    Sf = JCGECore.getparam(block.params, :Sf)
    constraint = nothing
    mcp_var = mcp ? EVar(:er, Any[]) : nothing
    eq_expr = EEq(
        EAdd([
            ESum(:i, commodities, EMul([
                EVar(:pWe, Any[EIndex(:i)]),
                EVar(:E, Any[EIndex(:i)]),
            ])),
            EParam(:Sf, Any[]),
        ]),
        ESum(:i, commodities, EMul([
            EVar(:pWm, Any[EIndex(:i)]),
            EVar(:M, Any[EIndex(:i)]),
        ])),
    )
    register_eq!(ctx, block, :eqBOP; info="sum(pWe[i]*E[i]) + Sf == sum(pWm[i]*M[i])",
        expr=eq_expr, mcp_var=mcp_var, constraint=constraint)

    return nothing
end

function JCGECore.build!(block::ExternalBalanceRemitBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    E = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    pwe = Dict{Symbol,Any}()
    pwm = Dict{Symbol,Any}()
    pwe_vals = hasproperty(block.params, :pwe) ? block.params.pwe : Dict{Symbol,Float64}()
    pwm_vals = hasproperty(block.params, :pwm) ? block.params.pwm : Dict{Symbol,Float64}()
    for i in traded
        E[i] = ensure_var!(ctx, model, global_var(:E, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
        pwe[i] = haskey(pwe_vals, i) ? pwe_vals[i] : ensure_var!(ctx, model, global_var(:pwe, i))
        pwm[i] = haskey(pwm_vals, i) ? pwm_vals[i] : ensure_var!(ctx, model, global_var(:pwm, i))
    end

    fsav = ensure_var!(ctx, model, global_var(:fsav))
    remit = ensure_var!(ctx, model, global_var(:remit))
    fbor = ensure_var!(ctx, model, global_var(:fbor))
    constraint = nothing
    mcp_var = mcp ? EVar(:er, Any[]) : nothing
    pwm_expr = hasproperty(block.params, :pwm) ? EParam(:pwm, Any[EIndex(:i)]) : EVar(:pwm, Any[EIndex(:i)])
    pwe_expr = hasproperty(block.params, :pwe) ? EParam(:pwe, Any[EIndex(:i)]) : EVar(:pwe, Any[EIndex(:i)])
    eq_expr = EEq(
        ESum(:i, traded, EMul([
            pwm_expr,
            EVar(:M, Any[EIndex(:i)]),
        ])),
        EAdd([
            ESum(:i, traded, EMul([
                pwe_expr,
                EVar(:E, Any[EIndex(:i)]),
            ])),
            EVar(:fsav, Any[]),
            EVar(:remit, Any[]),
            EVar(:fbor, Any[]),
        ]),
    )
    register_eq!(ctx, block, :caeq; info="sum(pwm*m) = sum(pwe*e) + fsav + remit + fbor",
        expr=eq_expr, mcp_var=mcp_var, constraint=constraint)
    return nothing
end

function JCGECore.build!(block::ForeignTradeBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model

    E = Dict{Symbol,Any}()
    M = Dict{Symbol,Any}()
    pWe = Dict{Symbol,Any}()
    pWm = Dict{Symbol,Any}()
    for i in commodities
        E[i] = ensure_var!(ctx, model, global_var(:E, i))
        M[i] = ensure_var!(ctx, model, global_var(:M, i))
        pWe[i] = ensure_var!(ctx, model, global_var(:pWe, i))
        pWm[i] = ensure_var!(ctx, model, global_var(:pWm, i))
    end

    for i in commodities
        E0_i = JCGECore.getparam(block.params, :E0, i)
        M0_i = JCGECore.getparam(block.params, :M0, i)
        pWe0_i = JCGECore.getparam(block.params, :pWe0, i)
        pWm0_i = JCGECore.getparam(block.params, :pWm0, i)
        sigma_i = JCGECore.getparam(block.params, :sigma, i)
        psi_i = JCGECore.getparam(block.params, :psi, i)
        constraint = nothing
        expr = EEq(
            EDiv(EVar(:E, Any[EIndex(:i)]), EParam(:E0, Any[EIndex(:i)])),
            EPow(
                EDiv(EVar(:pWe, Any[EIndex(:i)]), EParam(:pWe0, Any[EIndex(:i)])),
                ENeg(EParam(:sigma, Any[EIndex(:i)])),
            ),
        )
        register_eq!(ctx, block, :eqfe, i;
            info="E[i]/E0[i] == (pWe[i]/pWe0[i])^(-sigma[i])",
            expr=expr, index_names=(:i,), constraint=constraint)
        constraint = nothing
        expr = EEq(
            EDiv(EVar(:M, Any[EIndex(:i)]), EParam(:M0, Any[EIndex(:i)])),
            EPow(
                EDiv(EVar(:pWm, Any[EIndex(:i)]), EParam(:pWm0, Any[EIndex(:i)])),
                EParam(:psi, Any[EIndex(:i)]),
            ),
        )
        register_eq!(ctx, block, :eqfm, i;
            info="M[i]/M0[i] == (pWm[i]/pWm0[i])^(psi[i])",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::PriceAggregationBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model

    pz = Dict{Symbol,Any}()
    py = Dict{Symbol,Any}()
    pq = Dict{Symbol,Any}()
    for i in activities
        pz[i] = ensure_var!(ctx, model, global_var(:pz, i))
        py[i] = ensure_var!(ctx, model, global_var(:py, i))
    end
    for j in commodities
        pq[j] = ensure_var!(ctx, model, global_var(:pq, j))
    end

    for i in activities
        ay_i = JCGECore.getparam(block.params, :ay, i)
        ax_vals = Dict(j => JCGECore.getparam(block.params, :ax, j, i) for j in commodities)
        constraint = nothing
        expr = EEq(
            EVar(:pz, Any[EIndex(:i)]),
            EAdd([
                EMul([
                    EParam(:ay, Any[EIndex(:i)]),
                    EVar(:py, Any[EIndex(:i)]),
                ]),
                ESum(:j, commodities, EMul([
                    EParam(:ax, Any[EIndex(:j), EIndex(:i)]),
                    EVar(:pq, Any[EIndex(:j)]),
                ])),
            ]),
        )
        register_eq!(ctx, block, :eqpzs, i;
            info="pz[i] == ay[i]*py[i] + sum(ax[j,i]*pq[j])",
            expr=expr, index_names=(:i,), constraint=constraint)
    end

    return nothing
end

function JCGECore.build!(block::InternationalMarketBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    model = ctx.model
    goods = block.goods
    regions = block.regions
    mapping = block.mapping

    for i in goods
        for r in regions, rr in regions
            r == rr && continue
            key_r = (i, r)
            key_rr = (i, rr)
            haskey(mapping, key_r) || error("Missing mapping for $(key_r)")
            haskey(mapping, key_rr) || error("Missing mapping for $(key_rr)")
            sym_r = mapping[key_r]
            sym_rr = mapping[key_rr]
            pWe = ensure_var!(ctx, model, global_var(:pWe, sym_r))
            pWm = ensure_var!(ctx, model, global_var(:pWm, sym_rr))
            E = ensure_var!(ctx, model, global_var(:E, sym_r))
            M = ensure_var!(ctx, model, global_var(:M, sym_rr))
            constraint = nothing
            expr = EEq(
                EVar(:pWe, Any[sym_r]),
                EVar(:pWm, Any[sym_rr]),
            )
            register_eq!(ctx, block, :eqpw, i, r, rr;
                info="pWe[i,r] == pWm[i,rr]", expr=expr, index_names=(:i, :r, :rr), constraint=constraint)
            constraint = nothing
            expr = EEq(
                EVar(:E, Any[sym_r]),
                EVar(:M, Any[sym_rr]),
            )
            register_eq!(ctx, block, :eqw, i, r, rr;
                info="E[i,r] == M[i,rr]", expr=expr, index_names=(:i, :r, :rr), constraint=constraint)
        end
    end

    return nothing
end

function JCGECore.build!(block::ProductionMultilaborCDBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    labor = isempty(block.labor) ? spec.model.sets.factors : block.labor
    model = ctx.model
    mcp = mcp_enabled(block.params)

    xd = Dict{Symbol,Any}()
    pva = Dict{Symbol,Any}()
    k = Dict{Symbol,Any}()
    l = Dict{Tuple{Symbol,Symbol},Any}()
    wa = Dict{Symbol,Any}()

    for i in activities
        xd[i] = ensure_var!(ctx, model, global_var(:xd, i))
        pva[i] = ensure_var!(ctx, model, global_var(:pva, i))
        k[i] = ensure_var!(ctx, model, global_var(:k, i))
    end

    for lc in labor
        wa[lc] = ensure_var!(ctx, model, global_var(:wa, lc))
    end

    for i in activities, lc in labor
        l[(i, lc)] = ensure_var!(ctx, model, global_var(:l, i, lc))
    end

    for i in activities
        ad_i = JCGECore.getparam(block.params, :ad, i)
        wdist_vals = Dict(lc => JCGECore.getparam(block.params, :wdist, i, lc) for lc in labor)
        alphl_vals = Dict(lc => JCGECore.getparam(block.params, :alphl, lc, i) for lc in labor)
        active_labor = [lc for lc in labor if wdist_vals[lc] > 0.0]
        labor_share = sum(alphl_vals[lc] for lc in labor)

        constraint = nothing
        k_exp = EAdd([
            EConst(1.0),
            ENeg(ESum(:lc, labor, EParam(:alphl, Any[EIndex(:lc), EIndex(:i)]))),
        ])
        expr = EEq(
            EVar(:xd, Any[EIndex(:i)]),
            EMul([
                EParam(:ad, Any[EIndex(:i)]),
                EProd(:lc, active_labor, EPow(
                    EVar(:l, Any[EIndex(:i), EIndex(:lc)]),
                    EParam(:alphl, Any[EIndex(:lc), EIndex(:i)]),
                )),
                EPow(EVar(:k, Any[EIndex(:i)]), k_exp),
            ]),
        )
        mcp_var = mcp ? EVar(:pva, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:activity, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="xd[i] = ad[i]*prod(l^alphl)*k^(1-sum(alphl))", expr=expr, constraint=constraint, mcp_var=mcp_var))

        for lc in active_labor
            wdist_i = wdist_vals[lc]
            alpha_i = alphl_vals[lc]
            constraint = nothing
            expr = EEq(
                EMul([
                    EVar(:wa, Any[EIndex(:lc)]),
                    EParam(:wdist, Any[EIndex(:i), EIndex(:lc)]),
                    EVar(:l, Any[EIndex(:i), EIndex(:lc)]),
                ]),
                EMul([
                    EVar(:xd, Any[EIndex(:i)]),
                    EVar(:pva, Any[EIndex(:i)]),
                    EParam(:alphl, Any[EIndex(:lc), EIndex(:i)]),
                ]),
            )
            mcp_var = mcp ? EVar(:l, Any[EIndex(:i), EIndex(:lc)]) : nothing
            JCGERuntime.register_equation!(ctx; tag=:profitmax, block=block.name,
                payload=(indices=(i, lc), params=_payload_params(block), index_names=(:i, :lc),
                    info="wa*wdist*l = xd*pva*alphl", expr=expr, constraint=constraint, mcp_var=mcp_var))
        end
    end

    return nothing
end

function JCGECore.build!(block::LaborMarketClearingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    labor = isempty(block.labor) ? spec.model.sets.factors : block.labor
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for lc in labor
        ls = ensure_var!(ctx, model, global_var(:ls, lc))
        wa = ensure_var!(ctx, model, global_var(:wa, lc))
        l = Dict(i => ensure_var!(ctx, model, global_var(:l, i, lc)) for i in activities)
        constraint = nothing
        expr = EEq(
            ESum(:i, activities, EVar(:l, Any[EIndex(:i), EIndex(:lc)])),
            EVar(:ls, Any[EIndex(:lc)]),
        )
        mcp_var = mcp ? EVar(:wa, Any[EIndex(:lc)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:lmequil, block=block.name,
            payload=(indices=(lc,), params=_payload_params(block), index_names=(:lc,),
                info="sum_i l[i,lc] = ls[lc]", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::ActivityPriceIOBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for i in activities
        px = ensure_var!(ctx, model, global_var(:px, i))
        pva = ensure_var!(ctx, model, global_var(:pva, i))
        xd = ensure_var!(ctx, model, global_var(:xd, i))
        int = ensure_var!(ctx, model, global_var(:int, i))
        p = Dict(j => ensure_var!(ctx, model, global_var(:p, j)) for j in commodities)
        itax_i = JCGECore.getparam(block.params, :itax, i)
        io_vals = Dict(j => JCGECore.getparam(block.params, :io, j, i) for j in commodities)

        constraint = nothing
        expr = EEq(
            EMul([
                EVar(:px, Any[EIndex(:i)]),
                EAdd([EConst(1.0), ENeg(EParam(:itax, Any[EIndex(:i)]))]),
            ]),
            EAdd([
                EVar(:pva, Any[EIndex(:i)]),
                ESum(:j, commodities, EMul([
                    EParam(:io, Any[EIndex(:j), EIndex(:i)]),
                    EVar(:p, Any[EIndex(:j)]),
                ])),
            ]),
        )
        mcp_var = mcp ? EVar(:xd, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:actp, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="px*(1-itax) = pva + sum(io*p)", expr=expr, constraint=constraint, mcp_var=mcp_var))

        constraint = nothing
        expr = EEq(
            EVar(:int, Any[EIndex(:i)]),
            ESum(:j, activities, EMul([
                EParam(:io, Any[EIndex(:i), EIndex(:j)]),
                EVar(:xd, Any[EIndex(:j)]),
            ])),
        )
        mcp_var = mcp ? EVar(:int, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:inteq, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="int[i] = sum(io[i,j]*xd[j])", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::CapitalPriceCompositionBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for i in activities
        pk = ensure_var!(ctx, model, global_var(:pk, i))
        p = Dict(j => ensure_var!(ctx, model, global_var(:p, j)) for j in commodities)
        imat_vals = Dict(j => JCGECore.getparam(block.params, :imat, j, i) for j in commodities)
        constraint = nothing
        expr = EEq(
            EVar(:pk, Any[EIndex(:i)]),
            ESum(:j, commodities, EMul([
                EVar(:p, Any[EIndex(:j)]),
                EParam(:imat, Any[EIndex(:j), EIndex(:i)]),
            ])),
        )
        mcp_var = mcp ? EVar(:pk, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:pkdef, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="pk[i] = sum(p[j]*imat[j,i])", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::TradePriceLinkBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)
    er = ensure_var!(ctx, model, global_var(:er))
    include_pr = hasproperty(block.params, :include_pr) && block.params.include_pr
    pedef_mode = hasproperty(block.params, :pedef_mode) ? block.params.pedef_mode : :pe

    for i in traded
        pm = ensure_var!(ctx, model, global_var(:pm, i))
        pwm_val = hasproperty(block.params, :pwm) ? block.params.pwm[i] : ensure_var!(ctx, model, global_var(:pwm, i))
        tm = ensure_var!(ctx, model, global_var(:tm, i))
        pr = include_pr ? ensure_var!(ctx, model, global_var(:pr)) : 0.0
        constraint = nothing
        pwm_expr = hasproperty(block.params, :pwm) ? EParam(:pwm, Any[EIndex(:i)]) : EVar(:pwm, Any[EIndex(:i)])
        pr_expr = include_pr ? EVar(:pr, Any[]) : EConst(0.0)
        expr = EEq(
            EVar(:pm, Any[EIndex(:i)]),
            EMul([
                pwm_expr,
                EVar(:er, Any[]),
                EAdd([EConst(1.0), EVar(:tm, Any[EIndex(:i)]), pr_expr]),
            ]),
        )
        mcp_var = mcp ? EVar(:pm, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:pmdef, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="pm = pwm*er*(1+tm+pr)", expr=expr, constraint=constraint, mcp_var=mcp_var))

        pe = ensure_var!(ctx, model, global_var(:pe, i))
        pwe_val = hasproperty(block.params, :pwe) ? block.params.pwe[i] : ensure_var!(ctx, model, global_var(:pwe, i))
        te_i = JCGECore.getparam(block.params, :te, i)
        constraint = nothing
        pwe_expr = hasproperty(block.params, :pwe) ? EParam(:pwe, Any[EIndex(:i)]) : EVar(:pwe, Any[EIndex(:i)])
        expr = pedef_mode == :pwe ?
            EEq(
                EVar(:pe, Any[EIndex(:i)]),
                EMul([
                    pwe_expr,
                    EAdd([EConst(1.0), EParam(:te, Any[EIndex(:i)])]),
                    EVar(:er, Any[]),
                ]),
            ) :
            EEq(
                EMul([
                    EVar(:pe, Any[EIndex(:i)]),
                    EAdd([EConst(1.0), EParam(:te, Any[EIndex(:i)])]),
                ]),
                EMul([
                    pwe_expr,
                    EVar(:er, Any[]),
                ]),
            )
        mcp_var = mcp ? EVar(:pe, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:pedef, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="pe definition (mode=$(pedef_mode))", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::AbsorptionSalesBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for i in commodities
        p = ensure_var!(ctx, model, global_var(:p, i))
        px = ensure_var!(ctx, model, global_var(:px, i))
        x = ensure_var!(ctx, model, global_var(:x, i))
        pd = ensure_var!(ctx, model, global_var(:pd, i))
        xxd = ensure_var!(ctx, model, global_var(:xxd, i))
        pm = ensure_var!(ctx, model, global_var(:pm, i))
        m = ensure_var!(ctx, model, global_var(:m, i))
        term_m = i in traded ? pm * m : 0.0
        constraint = nothing
        term_m_expr = i in traded ? EMul([EVar(:pm, Any[EIndex(:i)]), EVar(:m, Any[EIndex(:i)])]) : EConst(0.0)
        expr = EEq(
            EMul([EVar(:p, Any[EIndex(:i)]), EVar(:x, Any[EIndex(:i)])]),
            EAdd([
                EMul([EVar(:pd, Any[EIndex(:i)]), EVar(:xxd, Any[EIndex(:i)])]),
                term_m_expr,
            ]),
        )
        mcp_var = mcp ? EVar(:p, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:absorption, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="p*x = pd*xxd + pm*m", expr=expr, constraint=constraint, mcp_var=mcp_var))

        px = ensure_var!(ctx, model, global_var(:px, i))
        xd = ensure_var!(ctx, model, global_var(:xd, i))
        pe = ensure_var!(ctx, model, global_var(:pe, i))
        e = ensure_var!(ctx, model, global_var(:e, i))
        term_e = i in traded ? pe * e : 0.0
        constraint = nothing
        term_e_expr = i in traded ? EMul([EVar(:pe, Any[EIndex(:i)]), EVar(:e, Any[EIndex(:i)])]) : EConst(0.0)
        expr = EEq(
            EMul([EVar(:px, Any[EIndex(:i)]), EVar(:xd, Any[EIndex(:i)])]),
            EAdd([
                EMul([EVar(:pd, Any[EIndex(:i)]), EVar(:xxd, Any[EIndex(:i)])]),
                term_e_expr,
            ]),
        )
        mcp_var = mcp ? EVar(:xxd, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:sales, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="px*xd = pd*xxd + pe*e", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::ArmingtonMXxdBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for i in traded
        x = ensure_var!(ctx, model, global_var(:x, i))
        m = ensure_var!(ctx, model, global_var(:m, i))
        xxd = ensure_var!(ctx, model, global_var(:xxd, i))
        pd = ensure_var!(ctx, model, global_var(:pd, i))
        pm = ensure_var!(ctx, model, global_var(:pm, i))
        ac_i = JCGECore.getparam(block.params, :ac, i)
        delta_i = JCGECore.getparam(block.params, :delta, i)
        rhoc_i = JCGECore.getparam(block.params, :rhoc, i)

        constraint = nothing
        expr = EEq(
            EVar(:x, Any[EIndex(:i)]),
            EMul([
                EParam(:ac, Any[EIndex(:i)]),
                EPow(
                    EAdd([
                        EMul([
                            EParam(:delta, Any[EIndex(:i)]),
                            EPow(EVar(:m, Any[EIndex(:i)]), ENeg(EParam(:rhoc, Any[EIndex(:i)]))),
                        ]),
                        EMul([
                            EAdd([EConst(1.0), ENeg(EParam(:delta, Any[EIndex(:i)]))]),
                            EPow(EVar(:xxd, Any[EIndex(:i)]), ENeg(EParam(:rhoc, Any[EIndex(:i)]))),
                        ]),
                    ]),
                    EDiv(ENeg(EConst(1.0)), EParam(:rhoc, Any[EIndex(:i)])),
                ),
            ]),
        )
        mcp_var = mcp ? EVar(:pd, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:armington, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="x = ac*(delta*m^-rhoc + (1-delta)*xxd^-rhoc)^(-1/rhoc)", expr=expr, constraint=constraint, mcp_var=mcp_var))

        constraint = nothing
        expr = EEq(
            EDiv(EVar(:m, Any[EIndex(:i)]), EVar(:xxd, Any[EIndex(:i)])),
            EPow(
                EDiv(
                    EMul([
                        EVar(:pd, Any[EIndex(:i)]),
                        EParam(:delta, Any[EIndex(:i)]),
                    ]),
                    EMul([
                        EVar(:pm, Any[EIndex(:i)]),
                        EAdd([EConst(1.0), ENeg(EParam(:delta, Any[EIndex(:i)]))]),
                    ]),
                ),
                EDiv(EConst(1.0), EAdd([EConst(1.0), EParam(:rhoc, Any[EIndex(:i)])])),
            ),
        )
        mcp_var = mcp ? EVar(:m, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:costmin, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="m/xxd = (pd/pm*delta/(1-delta))^(1/(1+rhoc))", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::CETXXDEBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for i in traded
        xd = ensure_var!(ctx, model, global_var(:xd, i))
        px = ensure_var!(ctx, model, global_var(:px, i))
        e = ensure_var!(ctx, model, global_var(:e, i))
        xxd = ensure_var!(ctx, model, global_var(:xxd, i))
        pe = ensure_var!(ctx, model, global_var(:pe, i))
        pd = ensure_var!(ctx, model, global_var(:pd, i))
        at_i = JCGECore.getparam(block.params, :at, i)
        gamma_i = JCGECore.getparam(block.params, :gamma, i)
        rhot_i = JCGECore.getparam(block.params, :rhot, i)

        constraint = nothing
        expr = EEq(
            EVar(:xd, Any[EIndex(:i)]),
            EMul([
                EParam(:at, Any[EIndex(:i)]),
                EPow(
                    EAdd([
                        EMul([
                            EParam(:gamma, Any[EIndex(:i)]),
                            EPow(EVar(:e, Any[EIndex(:i)]), EParam(:rhot, Any[EIndex(:i)])),
                        ]),
                        EMul([
                            EAdd([EConst(1.0), ENeg(EParam(:gamma, Any[EIndex(:i)]))]),
                            EPow(EVar(:xxd, Any[EIndex(:i)]), EParam(:rhot, Any[EIndex(:i)])),
                        ]),
                    ]),
                    EDiv(EConst(1.0), EParam(:rhot, Any[EIndex(:i)])),
                ),
            ]),
        )
        mcp_var = mcp ? EVar(:px, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:cet, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="xd = at*(gamma*e^rhot + (1-gamma)*xxd^rhot)^(1/rhot)", expr=expr, constraint=constraint, mcp_var=mcp_var))

        constraint = nothing
        expr = EEq(
            EDiv(EVar(:e, Any[EIndex(:i)]), EVar(:xxd, Any[EIndex(:i)])),
            EPow(
                EDiv(
                    EMul([
                        EVar(:pe, Any[EIndex(:i)]),
                        EAdd([EConst(1.0), ENeg(EParam(:gamma, Any[EIndex(:i)]))]),
                    ]),
                    EMul([
                        EVar(:pd, Any[EIndex(:i)]),
                        EParam(:gamma, Any[EIndex(:i)]),
                    ]),
                ),
                EDiv(EConst(1.0), EAdd([EParam(:rhot, Any[EIndex(:i)]), ENeg(EConst(1.0))])),
            ),
        )
        mcp_var = mcp ? EVar(:e, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:esupply, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="e/xxd = (pe/pd*(1-gamma)/gamma)^(1/(rhot-1))", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::ExportDemandBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    for i in traded
        e = ensure_var!(ctx, model, global_var(:e, i))
        pwe = ensure_var!(ctx, model, global_var(:pwe, i))
        e0_i = JCGECore.getparam(block.params, :e0, i)
        pwe0_i = JCGECore.getparam(block.params, :pwe0, i)
        eta_i = JCGECore.getparam(block.params, :eta, i)
        constraint = nothing
        expr = EEq(
            EDiv(EVar(:e, Any[EIndex(:i)]), EParam(:e0, Any[EIndex(:i)])),
            EPow(
                EDiv(EParam(:pwe0, Any[EIndex(:i)]), EVar(:pwe, Any[EIndex(:i)])),
                EParam(:eta, Any[EIndex(:i)]),
            ),
        )
        mcp_var = mcp ? EVar(:pwe, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:edemand, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="e/e0 = (pwe0/pwe)^eta", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::NontradedSupplyBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    nontraded = hasproperty(block.params, :nontraded) ? block.params.nontraded : Symbol[]
    model = ctx.model
    mcp = mcp_enabled(block.params)
    for i in nontraded
        xxd = ensure_var!(ctx, model, global_var(:xxd, i))
        xd = ensure_var!(ctx, model, global_var(:xd, i))
        x = ensure_var!(ctx, model, global_var(:x, i))
        pd = ensure_var!(ctx, model, global_var(:pd, i))
        p = ensure_var!(ctx, model, global_var(:p, i))
        px = ensure_var!(ctx, model, global_var(:px, i))
        constraint = nothing
        expr = EEq(
            EVar(:xxd, Any[EIndex(:i)]),
            EVar(:xd, Any[EIndex(:i)]),
        )
        mcp_var = mcp ? EVar(:pd, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:xxdsn, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="xxd = xd (nontraded)", expr=expr, constraint=constraint, mcp_var=mcp_var))
        constraint = nothing
        expr = EEq(
            EVar(:x, Any[EIndex(:i)]),
            EVar(:xxd, Any[EIndex(:i)]),
        )
        mcp_var = mcp ? EVar(:px, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:xsn, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="x = xxd (nontraded)", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::HouseholdShareDemandBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    y = ensure_var!(ctx, model, global_var(:y))
    mps = ensure_var!(ctx, model, global_var(:mps))
    for i in commodities
        p = ensure_var!(ctx, model, global_var(:p, i))
        cd = ensure_var!(ctx, model, global_var(:cd, i))
        cles_i = JCGECore.getparam(block.params, :cles, i)
        constraint = nothing
        expr = EEq(
            EMul([EVar(:p, Any[EIndex(:i)]), EVar(:cd, Any[EIndex(:i)])]),
            EMul([
                EParam(:cles, Any[EIndex(:i)]),
                EAdd([EConst(1.0), ENeg(EVar(:mps, Any[]))]),
                EVar(:y, Any[]),
            ]),
        )
        mcp_var = mcp ? EVar(:cd, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:cdeq, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="p*cd = cles*(1-mps)*y", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end

    hhsav = ensure_var!(ctx, model, global_var(:hhsav))
    constraint = nothing
    expr = EEq(
        EVar(:hhsav, Any[]),
        EMul([EVar(:mps, Any[]), EVar(:y, Any[])]),
    )
    mcp_var = mcp ? EVar(:hhsav, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:hhsaveq, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="hhsav = mps*y", expr=expr, constraint=constraint, mcp_var=mcp_var))
    return nothing
end

function JCGECore.build!(block::HouseholdShareDemandHHBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    households = isempty(block.households) ? spec.model.sets.institutions : block.households
    model = ctx.model
    mcp = mcp_enabled(block.params)

    p = Dict(i => ensure_var!(ctx, model, global_var(:p, i)) for i in commodities)
    cd = Dict(i => ensure_var!(ctx, model, global_var(:cd, i)) for i in commodities)
    yh = Dict(hh => ensure_var!(ctx, model, global_var(:yh, hh)) for hh in households)
    mps = Dict(hh => ensure_var!(ctx, model, global_var(:mps, hh)) for hh in households)
    htax_vals = Dict(hh => JCGECore.getparam(block.params, :htax, hh) for hh in households)

    for i in commodities
        cles_vals = Dict(hh => JCGECore.getparam(block.params, :cles, i, hh) for hh in households)
        constraint = nothing
        expr = EEq(
            EMul([EVar(:p, Any[EIndex(:i)]), EVar(:cd, Any[EIndex(:i)])]),
            ESum(:hh, households, EMul([
                EParam(:cles, Any[EIndex(:i), EIndex(:hh)]),
                EAdd([EConst(1.0), ENeg(EVar(:mps, Any[EIndex(:hh)]))]),
                EVar(:yh, Any[EIndex(:hh)]),
                EAdd([EConst(1.0), ENeg(EParam(:htax, Any[EIndex(:hh)]))]),
            ])),
        )
        mcp_var = mcp ? EVar(:cd, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:cdeq, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="p*cd = sum(cles*(1-mps)*yh*(1-htax))", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end

    hhsav = ensure_var!(ctx, model, global_var(:hhsav))
    constraint = nothing
    expr = EEq(
        EVar(:hhsav, Any[]),
        ESum(:hh, households, EMul([
            EVar(:mps, Any[EIndex(:hh)]),
            EVar(:yh, Any[EIndex(:hh)]),
            EAdd([EConst(1.0), ENeg(EParam(:htax, Any[EIndex(:hh)]))]),
        ])),
    )
    mcp_var = mcp ? EVar(:hhsav, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:hhsaveq, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="hhsav = sum(mps*yh*(1-htax))", expr=expr, constraint=constraint, mcp_var=mcp_var))
    return nothing
end

function JCGECore.build!(block::HouseholdIncomeLaborCapitalBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    labor = isempty(block.labor) ? spec.model.sets.factors : block.labor
    households = isempty(block.households) ? spec.model.sets.institutions : block.households
    model = ctx.model
    mcp = mcp_enabled(block.params)

    labor_hh = getproperty(block.params, :labor_household)
    capital_hh = getproperty(block.params, :capital_household)
    (labor_hh in households && capital_hh in households) || error("Missing labor/capital household labels.")

    yh = Dict(hh => ensure_var!(ctx, model, global_var(:yh, hh)) for hh in households)
    wa = Dict(lc => ensure_var!(ctx, model, global_var(:wa, lc)) for lc in labor)
    ls = Dict(lc => ensure_var!(ctx, model, global_var(:ls, lc)) for lc in labor)
    pva = Dict(i => ensure_var!(ctx, model, global_var(:pva, i)) for i in activities)
    xd = Dict(i => ensure_var!(ctx, model, global_var(:xd, i)) for i in activities)
    deprecia = ensure_var!(ctx, model, global_var(:deprecia))
    remit = ensure_var!(ctx, model, global_var(:remit))
    fbor = ensure_var!(ctx, model, global_var(:fbor))
    er = ensure_var!(ctx, model, global_var(:er))
    ypr = ensure_var!(ctx, model, global_var(:ypr))

    constraint = nothing
    expr = EEq(
        EVar(:yh, Any[labor_hh]),
        EAdd([
            ESum(:lc, labor, EMul([
                EVar(:wa, Any[EIndex(:lc)]),
                EVar(:ls, Any[EIndex(:lc)]),
            ])),
            EMul([EVar(:remit, Any[]), EVar(:er, Any[])]),
        ]),
    )
    mcp_var = mcp ? EVar(:yh, Any[labor_hh]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:labory, block=block.name,
        payload=(indices=(labor_hh,), params=_payload_params(block), index_names=(:hh,),
            info="yh[labor] = sum(wa*ls) + remit*er", expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:yh, Any[capital_hh]),
        EAdd([
            ESum(:i, activities, EMul([
                EVar(:pva, Any[EIndex(:i)]),
                EVar(:xd, Any[EIndex(:i)]),
            ])),
            ENeg(EVar(:deprecia, Any[])),
            ENeg(ESum(:lc, labor, EMul([
                EVar(:wa, Any[EIndex(:lc)]),
                EVar(:ls, Any[EIndex(:lc)]),
            ]))),
            EMul([EVar(:fbor, Any[]), EVar(:er, Any[])]),
            EVar(:ypr, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:yh, Any[capital_hh]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:capitaly, block=block.name,
        payload=(indices=(capital_hh,), params=_payload_params(block), index_names=(:hh,),
            info="yh[capital] = sum(pva*xd)-depr-sum(wa*ls)+fbor*er+ypr", expr=expr, constraint=constraint, mcp_var=mcp_var))
    return nothing
end

function JCGECore.build!(block::HouseholdTaxRevenueBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    households = isempty(block.households) ? spec.model.sets.institutions : block.households
    model = ctx.model
    mcp = mcp_enabled(block.params)

    tothhtax = ensure_var!(ctx, model, global_var(:tothhtax))
    yh = Dict(hh => ensure_var!(ctx, model, global_var(:yh, hh)) for hh in households)
    htax_vals = Dict(hh => JCGECore.getparam(block.params, :htax, hh) for hh in households)

    constraint = nothing
    expr = EEq(
        EVar(:tothhtax, Any[]),
        ESum(:hh, households, EMul([
            EParam(:htax, Any[EIndex(:hh)]),
            EVar(:yh, Any[EIndex(:hh)]),
        ])),
    )
    mcp_var = mcp ? EVar(:tothhtax, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:hhtaxdef, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="tothhtax = sum(htax*yh)", expr=expr, constraint=constraint, mcp_var=mcp_var))
    return nothing
end

function JCGECore.build!(block::HouseholdIncomeSumBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    households = isempty(block.households) ? spec.model.sets.institutions : block.households
    model = ctx.model
    mcp = mcp_enabled(block.params)

    y = ensure_var!(ctx, model, global_var(:y))
    yh = Dict(hh => ensure_var!(ctx, model, global_var(:yh, hh)) for hh in households)
    constraint = nothing
    expr = EEq(
        EVar(:y, Any[]),
        ESum(:hh, households, EVar(:yh, Any[EIndex(:hh)])),
    )
    mcp_var = mcp ? EVar(:y, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:gdp, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="y = sum(yh)", expr=expr, constraint=constraint, mcp_var=mcp_var))
    return nothing
end

function JCGECore.build!(block::GovernmentShareDemandBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)
    gdtot = ensure_var!(ctx, model, global_var(:gdtot))
    for i in commodities
        gd = ensure_var!(ctx, model, global_var(:gd, i))
        gles_i = JCGECore.getparam(block.params, :gles, i)
        constraint = nothing
        expr = EEq(
            EVar(:gd, Any[EIndex(:i)]),
            EMul([EParam(:gles, Any[EIndex(:i)]), EVar(:gdtot, Any[])]),
        )
        mcp_var = mcp ? EVar(:gd, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:gdeq, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="gd = gles*gdtot", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::InventoryDemandBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)
    for i in commodities
        dst = ensure_var!(ctx, model, global_var(:dst, i))
        xd = ensure_var!(ctx, model, global_var(:xd, i))
        dstr_i = JCGECore.getparam(block.params, :dstr, i)
        constraint = nothing
        expr = EEq(
            EVar(:dst, Any[EIndex(:i)]),
            EMul([EParam(:dstr, Any[EIndex(:i)]), EVar(:xd, Any[EIndex(:i)])]),
        )
        mcp_var = mcp ? EVar(:dst, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:dsteq, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="dst = dstr*xd", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::GovernmentFinanceBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    er = ensure_var!(ctx, model, global_var(:er))
    gr = ensure_var!(ctx, model, global_var(:gr))
    tariff = ensure_var!(ctx, model, global_var(:tariff))
    indtax = ensure_var!(ctx, model, global_var(:indtax))
    duty = ensure_var!(ctx, model, global_var(:duty))
    govsav = ensure_var!(ctx, model, global_var(:govsav))
    itax_vals = Dict(i => JCGECore.getparam(block.params, :itax, i) for i in commodities)
    te_vals = Dict(i => JCGECore.getparam(block.params, :te, i) for i in traded)

    tm_vars = Dict(i => ensure_var!(ctx, model, global_var(:tm, i)) for i in traded)
    m_vars = Dict(i => ensure_var!(ctx, model, global_var(:m, i)) for i in traded)
    pwm_vals = hasproperty(block.params, :pwm) ? block.params.pwm : Dict{Symbol,Float64}()
    pwm_vars = Dict(i => haskey(pwm_vals, i) ? pwm_vals[i] : ensure_var!(ctx, model, global_var(:pwm, i)) for i in traded)
    px_vars = Dict(i => ensure_var!(ctx, model, global_var(:px, i)) for i in commodities)
    xd_vars = Dict(i => ensure_var!(ctx, model, global_var(:xd, i)) for i in commodities)
    e_vars = Dict(i => ensure_var!(ctx, model, global_var(:e, i)) for i in traded)
    pe_vars = Dict(i => ensure_var!(ctx, model, global_var(:pe, i)) for i in traded)
    p_vars = Dict(i => ensure_var!(ctx, model, global_var(:p, i)) for i in commodities)
    gd_vars = Dict(i => ensure_var!(ctx, model, global_var(:gd, i)) for i in commodities)

    constraint = nothing
    pwm_expr = hasproperty(block.params, :pwm) ? EParam(:pwm, Any[EIndex(:i)]) : EVar(:pwm, Any[EIndex(:i)])
    expr = EEq(
        EVar(:tariff, Any[]),
        EMul([
            ESum(:i, traded, EMul([
                EVar(:tm, Any[EIndex(:i)]),
                EVar(:m, Any[EIndex(:i)]),
                pwm_expr,
            ])),
            EVar(:er, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:tariff, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:tariffdef, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="tariff = sum(tm*m*pwm)*er",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:indtax, Any[]),
        ESum(:i, commodities, EMul([
            EParam(:itax, Any[EIndex(:i)]),
            EVar(:px, Any[EIndex(:i)]),
            EVar(:xd, Any[EIndex(:i)]),
        ])),
    )
    mcp_var = mcp ? EVar(:indtax, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:indtaxdef, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="indtax = sum(itax*px*xd)",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:duty, Any[]),
        ESum(:i, traded, EMul([
            EParam(:te, Any[EIndex(:i)]),
            EVar(:e, Any[EIndex(:i)]),
            EVar(:pe, Any[EIndex(:i)]),
        ])),
    )
    mcp_var = mcp ? EVar(:duty, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:dutydef, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="duty = sum(te*e*pe)",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:gr, Any[]),
        EAdd([EVar(:tariff, Any[]), EVar(:duty, Any[]), EVar(:indtax, Any[])]),
    )
    mcp_var = mcp ? EVar(:gr, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:greq, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="gr = tariff + duty + indtax",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:gr, Any[]),
        EAdd([
            ESum(:i, commodities, EMul([
                EVar(:p, Any[EIndex(:i)]),
                EVar(:gd, Any[EIndex(:i)]),
            ])),
            EVar(:govsav, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:govsav, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:gruse, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="gr = sum(p*gd) + govsav",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    return nothing
end

function JCGECore.build!(block::GovernmentRevenueBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    er = ensure_var!(ctx, model, global_var(:er))
    gr = ensure_var!(ctx, model, global_var(:gr))
    tariff = ensure_var!(ctx, model, global_var(:tariff))
    indtax = ensure_var!(ctx, model, global_var(:indtax))
    netsub = ensure_var!(ctx, model, global_var(:netsub))
    tothhtax = ensure_var!(ctx, model, global_var(:tothhtax))
    govsav = ensure_var!(ctx, model, global_var(:govsav))
    itax_vals = Dict(i => JCGECore.getparam(block.params, :itax, i) for i in commodities)
    te_vals = Dict(i => JCGECore.getparam(block.params, :te, i) for i in traded)

    tm_vars = Dict(i => ensure_var!(ctx, model, global_var(:tm, i)) for i in traded)
    m_vars = Dict(i => ensure_var!(ctx, model, global_var(:m, i)) for i in traded)
    pwm_vals = hasproperty(block.params, :pwm) ? block.params.pwm : Dict{Symbol,Float64}()
    pwm_vars = Dict(i => haskey(pwm_vals, i) ? pwm_vals[i] : ensure_var!(ctx, model, global_var(:pwm, i)) for i in traded)
    px_vars = Dict(i => ensure_var!(ctx, model, global_var(:px, i)) for i in commodities)
    xd_vars = Dict(i => ensure_var!(ctx, model, global_var(:xd, i)) for i in commodities)
    e_vars = Dict(i => ensure_var!(ctx, model, global_var(:e, i)) for i in traded)
    pwe_vals = hasproperty(block.params, :pwe) ? block.params.pwe : Dict{Symbol,Float64}()
    pwe_vars = Dict(i => haskey(pwe_vals, i) ? pwe_vals[i] : ensure_var!(ctx, model, global_var(:pwe, i)) for i in traded)
    p_vars = Dict(i => ensure_var!(ctx, model, global_var(:p, i)) for i in commodities)
    gd_vars = Dict(i => ensure_var!(ctx, model, global_var(:gd, i)) for i in commodities)

    constraint = nothing
    pwm_expr = hasproperty(block.params, :pwm) ? EParam(:pwm, Any[EIndex(:i)]) : EVar(:pwm, Any[EIndex(:i)])
    expr = EEq(
        EVar(:tariff, Any[]),
        EMul([
            ESum(:i, traded, EMul([
                EVar(:tm, Any[EIndex(:i)]),
                EVar(:m, Any[EIndex(:i)]),
                pwm_expr,
            ])),
            EVar(:er, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:tariff, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:tariffdef, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="tariff = sum(tm*m*pwm)*er",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:indtax, Any[]),
        ESum(:i, commodities, EMul([
            EParam(:itax, Any[EIndex(:i)]),
            EVar(:px, Any[EIndex(:i)]),
            EVar(:xd, Any[EIndex(:i)]),
        ])),
    )
    mcp_var = mcp ? EVar(:indtax, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:indtaxdef, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="indtax = sum(itax*px*xd)",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    pwe_expr = hasproperty(block.params, :pwe) ? EParam(:pwe, Any[EIndex(:i)]) : EVar(:pwe, Any[EIndex(:i)])
    expr = EEq(
        EVar(:netsub, Any[]),
        EMul([
            ESum(:i, traded, EMul([
                EParam(:te, Any[EIndex(:i)]),
                EVar(:e, Any[EIndex(:i)]),
                pwe_expr,
            ])),
            EVar(:er, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:netsub, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:netsubdef, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="netsub = sum(te*e*pwe)*er",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:gr, Any[]),
        EAdd([
            EVar(:tariff, Any[]),
            ENeg(EVar(:netsub, Any[])),
            EVar(:indtax, Any[]),
            EVar(:tothhtax, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:gr, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:greq, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="gr = tariff - netsub + indtax + tothhtax",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:gr, Any[]),
        EAdd([
            ESum(:i, commodities, EMul([
                EVar(:p, Any[EIndex(:i)]),
                EVar(:gd, Any[EIndex(:i)]),
            ])),
            EVar(:govsav, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:govsav, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:gruse, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="gr = sum(p*gd) + govsav",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    return nothing
end

function JCGECore.build!(block::ImportPremiumIncomeBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    traded = hasproperty(block.params, :traded) ? block.params.traded : commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)

    ypr = ensure_var!(ctx, model, global_var(:ypr))
    er = ensure_var!(ctx, model, global_var(:er))
    pr = ensure_var!(ctx, model, global_var(:pr))
    pwm_vars = Dict(i => ensure_var!(ctx, model, global_var(:pwm, i)) for i in traded)
    m_vars = Dict(i => ensure_var!(ctx, model, global_var(:m, i)) for i in traded)

    constraint = nothing
    pwm_expr = hasproperty(block.params, :pwm) ? EParam(:pwm, Any[EIndex(:i)]) : EVar(:pwm, Any[EIndex(:i)])
    expr = EEq(
        EVar(:ypr, Any[]),
        EMul([
            ESum(:i, traded, EMul([
                pwm_expr,
                EVar(:m, Any[EIndex(:i)]),
            ])),
            EVar(:er, Any[]),
            EVar(:pr, Any[]),
        ]),
    )
    mcp_var = mcp ? EVar(:ypr, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:premium, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="ypr = sum(pwm*m)*er*pr",
            expr=expr, constraint=constraint, mcp_var=mcp_var))
    return nothing
end

function JCGECore.build!(block::GDPIncomeBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    model = ctx.model
    mcp = mcp_enabled(block.params)
    y = ensure_var!(ctx, model, global_var(:y))
    deprecia = ensure_var!(ctx, model, global_var(:deprecia))
    pva_vars = Dict(i => ensure_var!(ctx, model, global_var(:pva, i)) for i in activities)
    xd_vars = Dict(i => ensure_var!(ctx, model, global_var(:xd, i)) for i in activities)
    constraint = nothing
    expr = EEq(
        EVar(:y, Any[]),
        EAdd([
            ESum(:i, activities, EMul([
                EVar(:pva, Any[EIndex(:i)]),
                EVar(:xd, Any[EIndex(:i)]),
            ])),
            ENeg(EVar(:deprecia, Any[])),
        ]),
    )
    mcp_var = mcp ? EVar(:y, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:gdp, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="y = sum(pva*xd) - deprecia",
            expr=expr, constraint=constraint, mcp_var=mcp_var))
    return nothing
end

function JCGECore.build!(block::SavingsInvestmentBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    activities = isempty(block.activities) ? spec.model.sets.activities : block.activities
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)
    use_invest = hasproperty(block.params, :use_invest) && block.params.use_invest

    deprecia = ensure_var!(ctx, model, global_var(:deprecia))
    savings = ensure_var!(ctx, model, global_var(:savings))
    invest = use_invest ? ensure_var!(ctx, model, global_var(:invest)) : savings
    hhsav = ensure_var!(ctx, model, global_var(:hhsav))
    govsav = ensure_var!(ctx, model, global_var(:govsav))
    fsav = ensure_var!(ctx, model, global_var(:fsav))
    er = ensure_var!(ctx, model, global_var(:er))
    depr_vals = Dict(i => JCGECore.getparam(block.params, :depr, i) for i in activities)
    pk_vars = Dict(i => ensure_var!(ctx, model, global_var(:pk, i)) for i in activities)
    k_vars = Dict(i => ensure_var!(ctx, model, global_var(:k, i)) for i in activities)
    dk_vars = Dict(i => ensure_var!(ctx, model, global_var(:dk, i)) for i in activities)
    dst_vars = Dict(j => ensure_var!(ctx, model, global_var(:dst, j)) for j in commodities)
    p_vars = Dict(j => ensure_var!(ctx, model, global_var(:p, j)) for j in commodities)

    constraint = nothing
    expr = EEq(
        EVar(:deprecia, Any[]),
        ESum(:i, activities, EMul([
            EParam(:depr, Any[EIndex(:i)]),
            EVar(:pk, Any[EIndex(:i)]),
            EVar(:k, Any[EIndex(:i)]),
        ])),
    )
    mcp_var = mcp ? EVar(:deprecia, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:depreq, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="deprecia = sum(depr*pk*k)",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    constraint = nothing
    expr = EEq(
        EVar(:savings, Any[]),
        EAdd([
            EVar(:hhsav, Any[]),
            EVar(:govsav, Any[]),
            EVar(:deprecia, Any[]),
            EMul([EVar(:fsav, Any[]), EVar(:er, Any[])]),
        ]),
    )
    mcp_var = mcp ? EVar(:savings, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:totsav, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="savings = hhsav + govsav + deprecia + fsav*er",
            expr=expr, constraint=constraint, mcp_var=mcp_var))

    for i in activities
        kio_i = JCGECore.getparam(block.params, :kio, i)
        constraint = nothing
        invest_expr = use_invest ? EVar(:invest, Any[]) : EVar(:savings, Any[])
        expr = EEq(
            EMul([EVar(:pk, Any[EIndex(:i)]), EVar(:dk, Any[EIndex(:i)])]),
            EAdd([
                EMul([EParam(:kio, Any[EIndex(:i)]), invest_expr]),
                ENeg(EMul([
                    EParam(:kio, Any[EIndex(:i)]),
                    ESum(:j, commodities, EMul([
                        EVar(:dst, Any[EIndex(:j)]),
                        EVar(:p, Any[EIndex(:j)]),
                    ])),
                ])),
            ]),
        )
        mcp_var = mcp ? EVar(:dk, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:prodinv, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="pk*dk = kio*invest - kio*sum(dst*p)", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end

    for i in activities
        id = ensure_var!(ctx, model, global_var(:id, i))
        constraint = nothing
        expr = EEq(
            EVar(:id, Any[EIndex(:i)]),
            ESum(:j, activities, EMul([
                EParam(:imat, Any[EIndex(:i), EIndex(:j)]),
                EVar(:dk, Any[EIndex(:j)]),
            ])),
        )
        mcp_var = mcp ? EVar(:id, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:ieq, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="id[i] = sum(imat[i,j]*dk[j])", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end

    return nothing
end

function JCGECore.build!(block::FinalDemandClearingBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)
    for i in commodities
        x = ensure_var!(ctx, model, global_var(:x, i))
        int = ensure_var!(ctx, model, global_var(:int, i))
        cd = ensure_var!(ctx, model, global_var(:cd, i))
        gd = ensure_var!(ctx, model, global_var(:gd, i))
        id = ensure_var!(ctx, model, global_var(:id, i))
        dst = ensure_var!(ctx, model, global_var(:dst, i))
        constraint = nothing
        expr = EEq(
            EVar(:x, Any[EIndex(:i)]),
            EAdd([
                EVar(:int, Any[EIndex(:i)]),
                EVar(:cd, Any[EIndex(:i)]),
                EVar(:gd, Any[EIndex(:i)]),
                EVar(:id, Any[EIndex(:i)]),
                EVar(:dst, Any[EIndex(:i)]),
            ]),
        )
        mcp_var = mcp ? EVar(:x, Any[EIndex(:i)]) : nothing
        JCGERuntime.register_equation!(ctx; tag=:equil, block=block.name,
            payload=(indices=(i,), params=_payload_params(block), index_names=(:i,),
                info="x = int + cd + gd + id + dst", expr=expr, constraint=constraint, mcp_var=mcp_var))
    end
    return nothing
end

function JCGECore.build!(block::ConsumptionObjectiveBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    commodities = isempty(block.commodities) ? spec.model.sets.commodities : block.commodities
    model = ctx.model
    mcp = mcp_enabled(block.params)
    omega = ensure_var!(ctx, model, global_var(:omega))
    cd = Dict(i => ensure_var!(ctx, model, global_var(:cd, i)) for i in commodities)
    expr = EEq(
        EVar(:omega, Any[]),
        EProd(:i, commodities, EPow(
            EVar(:cd, Any[EIndex(:i)]),
            EParam(:alpha, Any[EIndex(:i)]),
        )),
    )
    mcp_var = mcp ? EVar(:omega, Any[]) : nothing
    JCGERuntime.register_equation!(ctx; tag=:objective, block=block.name,
        payload=(indices=(), params=_payload_params(block), info="omega = prod(cd^alpha)", expr=expr, constraint=nothing,
            mcp_var=mcp_var, objective_expr=EVar(:omega, Any[]), objective_sense=:Max))
    return nothing
end

function JCGECore.build!(block::InitialValuesBlock, ctx::JCGERuntime.KernelContext, spec::JCGECore.RunSpec)
    model = ctx.model
    start = hasproperty(block.params, :start) ? block.params.start : Dict{Symbol,Float64}()
    lower = hasproperty(block.params, :lower) ? block.params.lower : Dict{Symbol,Float64}()
    upper = hasproperty(block.params, :upper) ? block.params.upper : Dict{Symbol,Float64}()
    fixed = hasproperty(block.params, :fixed) ? block.params.fixed : Dict{Symbol,Float64}()

    for (name, value) in start
        var = ensure_var!(ctx, model, global_var(Symbol(name)))
        if model isa JuMP.Model
            JuMP.set_start_value(var, value)
        end
        register_eq!(ctx, block, :start, name; info="start $(name) = $(value)", constraint=nothing)
    end

    for (name, value) in lower
        var = ensure_var!(ctx, model, global_var(Symbol(name)))
        if model isa JuMP.Model
            JuMP.set_lower_bound(var, value)
        end
        register_eq!(ctx, block, :lower, name; info="lower $(name) = $(value)", constraint=nothing)
    end

    for (name, value) in upper
        var = ensure_var!(ctx, model, global_var(Symbol(name)))
        if model isa JuMP.Model
            JuMP.set_upper_bound(var, value)
        end
        register_eq!(ctx, block, :upper, name; info="upper $(name) = $(value)", constraint=nothing)
    end

    for (name, value) in fixed
        var = ensure_var!(ctx, model, global_var(Symbol(name)))
        if model isa JuMP.Model
            JuMP.fix(var, value; force=true)
        end
        register_eq!(ctx, block, :fixed, name; info="fixed $(name) = $(value)", constraint=nothing)
    end

    return nothing
end

function apply_start(spec::JCGECore.RunSpec, start::Dict{Symbol,<:Real};
    lower::Union{Nothing,Dict{Symbol,<:Real}}=nothing,
    upper::Union{Nothing,Dict{Symbol,<:Real}}=nothing,
    fixed::Union{Nothing,Dict{Symbol,<:Real}}=nothing)
    blocks = copy(spec.model.blocks)
    start_vals = Dict{Symbol,Float64}()
    for (name, value) in start
        start_vals[name] = Float64(value)
    end
    lower_vals = Dict{Symbol,Float64}()
    if lower !== nothing
        for (name, value) in lower
            lower_vals[name] = Float64(value)
        end
    end
    upper_vals = Dict{Symbol,Float64}()
    if upper !== nothing
        for (name, value) in upper
            upper_vals[name] = Float64(value)
        end
    end
    fixed_vals = Dict{Symbol,Float64}()
    if fixed !== nothing
        for (name, value) in fixed
            fixed_vals[name] = Float64(value)
        end
    end
    init_block = InitialValuesBlock(:init, (start = start_vals, lower = lower_vals, upper = upper_vals, fixed = fixed_vals))
    replaced = false
    for i in eachindex(blocks)
        if blocks[i] isa InitialValuesBlock
            blocks[i] = init_block
            replaced = true
            break
        end
    end
    if !replaced
        push!(blocks, init_block)
    end
    ms = JCGECore.ModelSpec(blocks, spec.model.sets, spec.model.mappings)
    return JCGECore.RunSpec(spec.name, ms, spec.closure, spec.scenario)
end

function rerun!(spec::JCGECore.RunSpec; from, optimizer=nothing,
    dataset_id::String="jcge", tol::Real=1e-6, description::Union{String,Nothing}=nothing)
    state = JCGERuntime.snapshot_state(from)
    spec2 = apply_start(spec, state.start; lower=state.lower, upper=state.upper, fixed=state.fixed)
    return JCGERuntime.run!(spec2; optimizer=optimizer, dataset_id=dataset_id, tol=tol, description=description)
end

end # module
