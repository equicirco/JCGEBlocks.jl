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

## [0.1.0] - 2026-01-18
### Added
- Core CGE block catalog covering production (CD, Leontief, sector PF, multilabor), trade (Armington, CET, export demand, nontraded supply), and market-clearing blocks.
- Institution blocks for households, government, saving, investment, and utility with regional and income variants where applicable.
- Price linkage, numeraire, closure, and price/index composition blocks for equilibrium bookkeeping.
- External balance, foreign trade, and remittances support for open-economy setups.
- Activity analysis, commodity market clearing, and initial-value helpers for model setup and validation.
- Helper constructors and MCP-compatible constraint wiring for consistent block assembly.
