# JCGEBlocks Changelog
All notable changes to this project will be documented in this file.
Releases use semantic versioning as in 'MAJOR.MINOR.PATCH'.

## Change entries
Added: For new features that have been added.
Changed: For changes in existing functionality.
Deprecated: For once-stable features removed in upcoming releases.
Removed: For features removed in this release.
Fixed: For any bug fixes.
Security: For vulnerabilities.

## [0.1.6] - 2026-07-17
### Fixed
- Generic production blocks now honour an optional `positive_lower` parameter
  for outputs, factor inputs, and prices, allowing calibrated models with
  small observed activities to retain their feasible reference point.

## [0.1.5] - 2026-07-17
### Fixed
- Removed unused direct multiplications from `AbsorptionSalesBlock` so it
  builds correctly with both symbolic and JuMP-backed kernel contexts.

## [0.1.4] - 2026-07-16
### Added
- `InventoryTreatment` and `inventory_treatment` provide one typed inventory
  convention shared by output-allocation, market-clearing, and
  saving--investment blocks.
- Both `:stock_change` and `:marketed_demand` conventions are available for
  the single-region and multi-region block families.

### Changed
- Multi-region inventory changes now use one signed parameter keyed by model
  good, rather than separate product-origin and commodity parameters.
- Inventory-aware blocks validate that one model does not mix treatments.

## [0.1.3] - 2026-07-16
### Added
- `closure_condition` helper for constructing stable closure-condition keys
  from block equations, including multi-region market and investment-pool
  identities.

## [0.1.2] - 2026-07-16
### Added
- Regional private-saving and household-demand blocks that derive household income from factor use, allowing fixed-real-factor-price closures with unused factor capacity.
- Regional government-demand, fixed-investment-demand, and composite-market-clearing blocks for calibrated multi-region SAM closures.
- Initial signed-inventory support in bilateral multi-region trade, regional
  composite market clearing, and regional investment-pool accounting,
  distinct from gross fixed-capital formation. Replaced by the shared
  `InventoryTreatment` interface in 0.1.4.

### Fixed
- Production CD--Leontief blocks now allow structural-zero intermediate coefficients to produce exactly zero intermediate flows.

## [0.1.1] - 2026-07-16
### Added
- Regional household price-index and fixed-real-factor-availability blocks for multi-region CGE closures.
- Support for fixing a model-defined price-index numeraire through `NumeraireBlock`.
- Bilateral multi-region Armington/CET trade block with shared route quantities, exact Cobb--Douglas limits, and ROW as an external counterpart rather than a modelled region.
- Regional external-account block that records each region's ROW trade balance.
- Regional investment-pool block that clears model-defined regional saving and investment through explicit transfers.

## [0.1.0] - 2026-01-18
### Added
- Core CGE block catalog covering production (CD, Leontief, sector PF, multilabor), trade (Armington, CET, export demand, nontraded supply), and market-clearing blocks.
- Institution blocks for households, government, saving, investment, and utility with regional and income variants where applicable.
- Price linkage, numeraire, closure, and price/index composition blocks for equilibrium bookkeeping.
- External balance, foreign trade, and remittances support for open-economy setups.
- Activity analysis, commodity market clearing, and initial-value helpers for model setup and validation.
- Helper constructors and MCP-compatible constraint wiring for consistent block assembly.
