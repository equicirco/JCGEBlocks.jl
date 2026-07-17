<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/src/assets/jcge_blocks_logo_dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/src/assets/jcge_blocks_logo_light.png">
  <img alt="JCGE Blocks logo" src="docs/src/assets/jcge_blocks_logo_light.png" height="150">
</picture>

# JCGEBlocks

## What is a CGE?
A Computable General Equilibrium (CGE) model is a quantitative economic model that represents an economy as interconnected markets for goods and services, factors of production, institutions, and the rest of the world. It is calibrated with data (typically a Social Accounting Matrix) and solved numerically as a system of nonlinear equations until equilibrium conditions (zero-profit, market-clearing, and income-balance) hold within tolerance.

## What is JCGE?
JCGE is a block-based CGE modeling and execution framework in Julia. It defines a shared RunSpec structure and reusable blocks so models can be assembled, validated, solved, and compared consistently across packages. See https://jcge.org for details.

## What is this package?
Standard CGE blocks built on the JCGE interfaces (https://jcge.org).

## Responsibilities
- Production blocks (nested production functions)
- Trade blocks (Armington/CET as needed)
- Institution blocks (households, government)
- Market clearing blocks
- Auxiliary-quantity blocks for model variables that must participate in
  equilibrium equations without becoming monetary SAM accounts

## Dependencies
- Depends on JCGECore, JCGERuntime, and the broader JCGE stack (https://jcge.org)

## How to cite

If you use the JCGE framework, please cite:

Boero, R. *JCGE - Julia Computable General Equilibrium Framework* [software], 2026.
DOI: 10.5281/zenodo.18282436
URL: https://JCGE.org

```bibtex
@software{boero_jcge_2026,
  title  = {JCGE - Julia Computable General Equilibrium Framework},
  author = {Boero, Riccardo},
  year   = {2026},
  doi    = {10.5281/zenodo.18282436},
  url    = {https://JCGE.org}
}
```

If you use this package, please cite:

Boero, R. *JCGEBlocks.jl - Reusable CGE blocks for JCGE.* [software], 2026.
DOI: 10.5281/zenodo.18290873
URL: https://blocks.jcge.org
SourceCode: https://github.com/equicirco/JCGEBlocks.jl

```bibtex
@software{boero_jcgeblocks_2026,
  title  = {JCGEBlocks.jl - Reusable CGE blocks for JCGE.},
  author = {Boero, Riccardo},
  year   = {2026},
  doi    = {10.5281/zenodo.18290873},
  url    = {https://blocks.jcge.org}
}
```

If you use a specific tagged release, please cite the version DOI assigned on Zenodo for that release (preferred for exact reproducibility).

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

Inventory accounting is selected once with
`inventory_treatment(:stock_change)` or
`inventory_treatment(:marketed_demand)` and passed to the inventory-aware
trade, market-clearing, and saving--investment blocks. See the usage guide for
the accounting implications of each treatment.

## Auxiliary quantities

`quantity_link`, `quantity_transformation`, `quantity_balance`, and
`quantity_capacity` provide a small, domain-neutral algebra for quantities
that are connected to the equilibrium system. They can represent any
calibrated auxiliary quantity: physical flows, technical requirements,
environmental pressures, stocks, or policy-relevant indicators. The blocks do
not assign units or numerical values. Mappings define the model structure and
the named `coefficient` and `capacity` parameter sets supply all numerical
inputs.

Use `quantity_link` to connect a quantity to an existing model variable, then
use transformations, signed balance identities, and capacities as required.
Inputs to a transformation, balance, or capacity block must have been defined
by an earlier block. Use `JCGEOutput` satellite reporting when a quantity is
only reported after a solve; use these Blocks primitives when it must constrain
or otherwise participate in the equilibrium model.

## Block catalog

- Production and activity: `ProductionBlock`, `ProductionCDBlock`,
  `ProductionCDLeontiefBlock`, `ProductionCDLeontiefSectorPFBlock`,
  `ProductionMultilaborCDBlock`, `ActivityAnalysisBlock`, and
  `ActivityPriceIOBlock`.
- Factor markets: `FactorSupplyBlock`, `FactorMarketClearingBlock`,
  `LaborMarketClearingBlock`, `MobileFactorMarketBlock`,
  `CapitalStockReturnBlock`, and `RegionalFactorAvailabilityBlock`.
- Households and utility: `HouseholdDemandBlock`, `HouseholdDemandCDBlock`,
  `HouseholdDemandCDXpBlock`, `HouseholdDemandCDHHBlock`,
  `HouseholdDemandCDXpRegionalBlock`, `HouseholdDemandIncomeBlock`,
  `RegionalHouseholdIncomeDemandBlock`, `UtilityBlock`, `UtilityCDBlock`,
  `UtilityCDXpBlock`, `UtilityCDHHBlock`, and `UtilityCDRegionalBlock`.
- Government, saving, and investment: `GovernmentBlock`,
  `GovernmentRegionalBlock`, `RegionalGovernmentDemandBlock`,
  `GovernmentBudgetBalanceBlock`, `GovernmentFinanceBlock`,
  `GovernmentRevenueBlock`, `PrivateSavingBlock`, `PrivateSavingRegionalBlock`,
  `PrivateSavingIncomeBlock`, `RegionalPrivateSavingIncomeBlock`,
  `InvestmentBlock`, `InvestmentRegionalBlock`,
  `RegionalFixedInvestmentDemandBlock`, `CompositeInvestmentBlock`,
  `InvestmentAllocationBlock`, `RegionalInvestmentPoolBlock`, and
  `SavingsInvestmentBlock`.
- Trade and external accounts: `ArmingtonCESBlock`, `ArmingtonMXxdBlock`,
  `TransformationCETBlock`, `CETXXDEBlock`, `MultiRegionTradeBlock`,
  `TradeRoute`, `ForeignTradeBlock`, `ExportDemandBlock`, `NontradedSupplyBlock`,
  `ImportQuotaBlock`, `ExternalBalanceBlock`, `ExternalBalanceVarPriceBlock`,
  `ExternalBalanceRemitBlock`, `RegionalExternalAccountBlock`, and
  `InternationalMarketBlock`.
- Prices and closures: `PriceLinkBlock`, `PriceEqualityBlock`,
  `ExchangeRateLinkBlock`, `ExchangeRateLinkRegionBlock`, `PriceIndexBlock`,
  `PriceLevelBlock`, `PriceAggregationBlock`, `TradePriceLinkBlock`,
  `NumeraireBlock`, and `ClosureBlock`.
- Market and final-demand accounting: `MarketClearingBlock`,
  `GoodsMarketClearingBlock`, `CommodityMarketClearingBlock`,
  `CompositeMarketClearingBlock`, `RegionalCompositeMarketClearingBlock`,
  `FinalDemandClearingBlock`, `HouseholdShareDemandBlock`,
  `HouseholdShareDemandHHBlock`, `GovernmentShareDemandBlock`,
  `InventoryDemandBlock`, `InventoryTreatment`, `AbsorptionSalesBlock`, and
  `ConsumerEndowmentCDBlock`.
- Other reusable mechanisms: `MonopolyRentBlock`, `CapitalPriceCompositionBlock`,
  `HouseholdIncomeLaborCapitalBlock`, `HouseholdTaxRevenueBlock`,
  `HouseholdIncomeSumBlock`, `ImportPremiumIncomeBlock`, `GDPIncomeBlock`,
  `ConsumptionObjectiveBlock`, and `InitialValuesBlock`.
- Auxiliary quantities: `QuantityLinkBlock`, `QuantityTransformationBlock`,
  `QuantityBalanceBlock`, and `QuantityCapacityBlock`.
