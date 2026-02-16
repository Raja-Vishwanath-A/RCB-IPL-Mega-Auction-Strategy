# RCB-IPL-Mega-Auction-Strategy
RCB IPL Mega Auction Strategy

This repository contains a comprehensive SQL-based analysis designed to build a data-driven auction strategy for the Royal Challengers Bangalore (RCB) team in the Indian Premier League (IPL). The goal is to identify players who best fit RCB’s team composition, maximize performance across seasons, and highlight strategic insights that can improve RCB’s chances of winning the IPL trophy.

📊 Project Overview

The project analyzes ball-by-ball match data, player performance, venue impact, and match outcomes to derive actionable insights for team strategy and auction decisions. It leverages advanced SQL techniques to extract meaningful patterns from historical IPL data.

🧠 Key Objectives

Identify top-performing batsmen and bowlers across seasons

Analyze performance metrics such as strike rate, batting average, and bowling economy

Evaluate home vs away match performance and venue influence

Derive insights on match outcomes, toss impact, and playoff performance

Propose an optimized auction strategy for RCB based on data findings

📁 Dataset Description

The analysis uses a dataset comprised of 20 tables, including:

Ball_By_Ball: Ball-level data for all matches

Matches: Match metadata, results and winners

Player: Player names and IDs

Season: IPL season information

Team: Team identification and names

Extra_Runs & Extra_Type: Extra runs conceded per delivery

Wicket_Taken & Out_Type: Dismissal details

Venue & Toss_Decision: Match context data

Win_By & Outcome: Victory details

Player_Match & Rolee: Player participation and roles

Batting_Style & Bowling_Style: Player skill attributes

City & Country: Location details

Umpire: Official match referees

🛠️ Methodology

The analysis followed a structured sequence:

Data Exploration and Cleaning

Examined relationships, null values, and table keys

Standardized inconsistent records for accurate joins

Player Performance Metrics

Batting: strike rate, batting average, runs per season

Bowling: wickets, average wickets, economy

Top Performer Extraction

Identified high-impact players based on performance metrics

Filtered players relevant to RCB strategy

Match Context Analysis

Home vs Away performance

Venue impact (e.g., Chinnaswamy Stadium)

Toss decision influence on match outcomes

Strategic Recommendations

Auction suggestions based on data insights

🧾 Results & Key Findings

RCB has historically relied on star players like Virat Kohli, AB de Villiers, Chris Gayle, Yuzvendra Chahal, and Mitchell Starc.

The team consistently qualifies for playoffs but lacks balanced squad depth and all-rounder contributions.

RCB’s performance is stronger when bowling first, especially at home venues.

RCB would benefit from investing in all-rounders and specialist bowlers to complement top batting talent.

Venue influence and chase strategies (like in Chinnaswamy Stadium) should inform auction and match tactics.

📈 Insights for RCB Auction Strategy

Based on the analysis:

Target balanced players: dependable middle-order batsmen and impactful bowlers

Include all-rounders for flexibility (e.g., Jadeja, Pollard, Russell)

Prioritize death-over bowling specialists

Leverage toss and match context data for in-play strategy

💻 SQL & Reporting

1300+ lines of SQL queries developed

80-page detailed analytical report created

Extensive use of:

CTEs

Window functions

Views

Aggregations

The project bridges the gap between solving isolated SQL problems and real-world analytical challenges.
