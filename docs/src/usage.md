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

All regional mappings, trade routes, elasticities, calibrated shares, prices,
and delivery factors are model inputs; the package provides no numerical
defaults. A zero Armington or CET exponent is represented exactly as the
Cobb--Douglas limit.

## Functional forms

Many blocks accept a `form` symbol to select a functional form (Cobb-Douglas,
CES, Leontief, etc.). Some blocks support per-entity mappings via a Dict.

## MCP support

Blocks can emit MCP-compatible constraints when `mcp=true` is supplied in params
for models solved with PATHSolver.
