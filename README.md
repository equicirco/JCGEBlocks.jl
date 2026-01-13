<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/src/assets/jcge_blocks_logo_dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/src/assets/jcge_blocks_logo_light.png">
  <img alt="JCGE Blocks logo" src="docs/src/assets/jcge_blocks_logo_light.png" height="150">
</picture>

# JCGEBlocks

## What is a CGE?
A Computable General Equilibrium (CGE) model is a quantitative economic model that represents an economy as interconnected markets for goods and services, factors of production, institutions, and the rest of the world. It is calibrated with data (typically a Social Accounting Matrix) and solved numerically as a system of nonlinear equations until equilibrium conditions (zero-profit, market-clearing, and income-balance) hold within tolerance.

## What is JCGE?
JCGE is a block-based CGE modeling and execution framework in Julia. It defines a shared RunSpec structure and reusable blocks so models can be assembled, validated, solved, and compared consistently across packages.

## What is this package?
Standard CGE blocks built on the JCGE interfaces.

## Responsibilities
- Production blocks (nested production functions)
- Trade blocks (Armington/CET as needed)
- Institution blocks (households, government)
- Market clearing blocks

## Dependencies
- Depends on JCGECore, JCGERuntime

## Naming and functional forms
Block names are composed as `Domain + Role + FunctionalForm` when relevant.
Examples: `ProductionCDBlock`, `UtilityCESBlock`, `TransformationCETBlock`.

For extensibility, blocks that support multiple forms also expose a `form` field
and can be constructed via a generic wrapper (e.g., `ProductionBlock(form=:cd)`).
This keeps the API stable while making the functional form explicit.

Production supports mixed forms via a per-activity map:
```julia
form = Dict(:a1=>:cd, :a2=>:cd_leontief)
prod = JCGEBlocks.ProductionBlock(:prod, activities, factors, commodities, form, params)
```
Using the helper `production(...; form=:cd)` will expand the symbol to a map.

## Helper constructors
For consistency, use the lower-case helpers (e.g., `production`, `household_demand`,
`utility`, `government`, `investment`) which build the general entry-point blocks.

### Single vs multi-region usage
Single-region models use the standard helpers:
```julia
prod = production(:prod, activities, factors, commodities; form=:cd, params=params)
hh = household_demand(:household, Symbol[], commodities, factors; form=:cd, consumption_var=:Xp, params=params)
util = utility(:utility, Symbol[], commodities; form=:cd, consumption_var=:Xp, params=(alpha=params.alpha,))
```

Multi-region models use the regional helpers and the world-market block:
```julia
gov = government_regional(:gov, goods_r, factors_r, :JPN, params)
hh = household_demand_regional(:hh, goods_r, factors_r, :JPN; params=params)
util = utility_regional(:utility, goods_by_region, (alpha=alpha,))
world = international_market(:world, goods, regions, mapping)
```

## Block catalog (planned)
- Production: `ProductionCDBlock`, `ProductionCESBlock`, `ProductionLeontiefBlock` (with `ProductionBlock(form=...)`)
- Production (sectoral factor prices): `ProductionCDLeontiefSectorPFBlock`
- Factor supply/endowment: fixed factor availability (labor/capital) and shocks
- Government: `GovernmentBudgetBlock` (taxes, spending, saving)
- Government budget balance: `GovernmentBudgetBalanceBlock`
- Investment: `InvestmentDemandBlock`, savings-investment identity
- Investment composition/allocation: `CompositeInvestmentBlock`, `InvestmentAllocationBlock`
- Household: `HouseholdDemandBlock`, `UtilityCDBlock`/`UtilityCESBlock`, private saving
- Household income demand: `HouseholdDemandIncomeBlock`
- Trade/Armington: `ArmingtonCESBlock`
- Transformation/CET: `TransformationCETBlock`
- Monopoly rent: `MonopolyRentBlock`
- Import quotas: `ImportQuotaBlock`
- Prices: `WorldPriceLinkBlock`, `ExchangeRateLinkBlock`
- External balance: balance of payments (foreign savings)
- Market clearing: `GoodsMarketClearingBlock`, `CompositeMarketClearingBlock`, `FactorMarketClearingBlock`
- Activity analysis (fixed coefficients): `ActivityAnalysisBlock`
- Endowment-based CD demand: `ConsumerEndowmentCDBlock`
- Commodity market clearing (MPSGE-style): `CommodityMarketClearingBlock`
- Factor mobility/capital stock: `MobileFactorMarketBlock`, `CapitalStockReturnBlock`
- Composite consumption/price level: `CompositeConsumptionBlock`, `PriceLevelBlock`
- Closure: numeraire + macro closure choices
