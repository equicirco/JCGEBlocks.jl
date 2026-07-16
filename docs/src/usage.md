# Usage

`JCGEBlocks` provides reusable blocks that emit equation ASTs and variables for
the [JCGE](https://jcge.org) framework.

## Build blocks

```julia
using JCGEBlocks

prod = production(:prod, activities, factors, goods; form=:cd, params=prod_params)
hh = household_demand(:household, Symbol[], goods, factors; form=:cd, params=hh_params)
market = composite_market_clearing(:market, goods, activities)
```

## Multi-region mechanisms

`regional_price_index` defines one price index per region and can also define a
common weighted index for use as a price-index numeraire. `regional_factor_availability`
keeps factor use within each region's endowment while fixing factor prices in
real terms relative to that regional index. Both blocks require all weights,
endowments, real prices, and numerical lower bounds in their parameter inputs.

`multiregion_trade` takes an explicit list of `TradeRoute`s. A route represents
one origin--destination quantity and is used by both the origin's CET supply
allocation and the destination's Armington composite. This is suitable for
bilateral trade among modelled regions. `:ROW` can be an endpoint of a route,
with a route-specific exogenous world price, but it is not a modelled region.
`regional_external_account` records each region's resulting ROW trade balance.
`regional_investment_pool` values each region's investment demand, records the
associated signed pool transfer, and clears those transfers across the
modelled regions. Saving and investment behaviour remain defined by the model
that uses the block.

For a calibrated multi-region SAM, `regional_private_saving_income` and
`regional_household_income_demand` derive household saving and consumption
from the factor income actually earned in each region. This allows fixed real
factor prices with unused factor capacity. `regional_government_demand` uses
calibrated direct- and output-tax rates, spending shares, and a government
saving share; its government-saving balance may therefore be positive or
negative. `regional_fixed_investment_demand` fixes gross fixed-capital
formation at its calibrated quantities, while
`regional_composite_market_clearing` clears Armington composites against
intermediate, household, government, fixed-investment, and optional signed
inventory demand.

Signed `inventory_change[product, origin]` parameters in `multiregion_trade`
separate production from marketed sales. The corresponding
`inventory_quantity[good]` values can be supplied to the composite-market and
investment-pool blocks, so changes in inventories affect market clearing and
investment finance without being treated as fixed-capital formation.

All regional mappings, trade routes, elasticities, calibrated shares, prices,
and delivery factors are model inputs; the package provides no numerical
defaults. A zero Armington or CET exponent is represented exactly as the
Cobb--Douglas limit.

## Closure conditions

Each equation emitted by a block has a stable closure-condition key: the block
name, equation tag, and its indices. Use `closure_condition` when declaring a
model closure. For example, the investment-pool identity can remain in the
equation inventory as a post-solution accounting check:

```julia
using JCGECore: ClosureSpec

pool_check = closure_condition(pool, :investment_pool_clearing)
closure = ClosureSpec(:P_HH_COMMON;
    kind = :price_index,
    condition_roles = Dict(pool_check => :accounting_check),
)
```

`JCGERuntime` 0.1.4 or later applies these roles during compilation and
evaluates accounting checks after solution.

## Functional forms

Many blocks accept a `form` symbol to select a functional form (Cobb-Douglas,
CES, Leontief, etc.). Some blocks support per-entity mappings via a Dict.

## MCP support

Blocks can emit MCP-compatible constraints when `mcp=true` is supplied in params
for models solved with PATHSolver.
