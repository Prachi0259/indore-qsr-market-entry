# Indore QSR Market Entry

SQL-based market-entry analysis for an affordable-premium QSR considering expansion into Indore.

## Business Problem

A QSR brand with a target AOV of ₹250–₹450 per person wants to assess the Indore market before entering.

The analysis evaluates:
- market demand
- competitive intensity
- pricing
- customer engagement
- locality × proposition whitespace
- potential market-entry priorities

## Analytical Workflow

Raw restaurant data → Data cleaning → Branch-level market → Proposition classification → Locality × proposition analysis → Opportunity scoring → Executive shortlist → Power BI

## Key Scale

- 2,844 source records retained in the cleaned staging dataset
- 43 Indore localities in the qualified opportunity analysis
- 10 proposition categories
- 113 qualified locality × proposition combinations
- 164K+ customer votes across qualified opportunities

## Opportunity Framework

The opportunity score combines:
- 50% customer engagement
- 30% supply whitespace
- 20% price whitespace

The score is a prioritization tool, not a forecast of revenue or market share.

## Important Data Notes

The source is a historical/public restaurant dataset rather than a live 2026 market census.

`average_cost_for_two` represents approximate spend for two people. Therefore, Brand X's ₹250–₹450 per-person target is represented using a ₹500–₹900 two-person proxy.

Review text is excluded from the core analysis because the supplied review field contains cross-location references. This avoids unsupported location-specific sentiment claims.

## Project Structure

```text
indore-qsr-market-entry/
├── 01_data/
├── 02_sql/
├── 03_powerbi/
├── 04_outputs/
├── docs/
├── .gitignore
└── README.md
```

## Tools

MySQL | SQL | Power BI | DAX

## Resume Version

**Indore QSR Market Entry | SQL, Power BI**

Evaluated 2,844 restaurant records across 43 Indore localities using SQL-based quantitative analysis to assess market demand, competitive intensity, pricing and customer engagement across 10 QSR propositions, enabling a structured market-entry assessment.

Developed a decision-analytics framework scoring 113 locality–proposition combinations on customer engagement, supply and price whitespace, translating 164K+ customer votes into actionable location and proposition priorities for an affordable-premium QSR.
