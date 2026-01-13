# Usage

`JCGEBlocks` provides reusable blocks that emit equation ASTs and variables.

## Build blocks

```julia
using JCGEBlocks

prod = production(:prod, activities, factors, goods; form=:cd, params=prod_params)
hh = household_demand(:household, Symbol[], goods, factors; form=:cd, params=hh_params)
market = composite_market_clearing(:market, goods, activities)
```

## Functional forms

Many blocks accept a `form` symbol to select a functional form (Cobb-Douglas,
CES, Leontief, etc.). Some blocks support per-entity mappings via a Dict.

## MCP support

Blocks can emit MCP-compatible constraints when `mcp=true` is supplied in params
for models solved with PATHSolver.

