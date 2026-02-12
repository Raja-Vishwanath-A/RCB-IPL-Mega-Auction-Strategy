-- RCB IPL Auction Strategy Project - A Raja Vishwanath


-- //////////////////////////////////// OBJECTIVE QUESTIONS ///////////////////////////////////


-- 1.	List the different dtypes of columns in table “ball_by_ball” (using information schema)

Select
    Column_Name, 
    Data_type
From information_schema.columns
Where Table_Name = 'ball_by_ball';


-- 2.	What is the total number of run scored in 1st season by RCB (bonus : also include the extra runs using the extra runs table)

With Total_ball_run_Data as(
	Select
		bb.* , m.season_id,
		Extra_Type_Id, 
		Extra_Runs
	From ball_by_ball bb
	Left Join extra_runs er on
	bb.match_id = er.match_id and
	bb.Innings_No = er.Innings_No and
	bb.Over_Id = er.Over_Id and
	bb.Ball_Id = er.Ball_Id
    left Join Matches m on m.match_id = bb.match_id
)
Select
 Sum(coalesce(Runs_Scored,0) + coalesce(extra_runs,0)) as Total_runs
From Total_ball_run_Data
Where Team_Batting = (Select Team_id from team Where team_name = 'Royal Challengers Bangalore') and 
	season_id = (Select min(Season_id) From matches);



-- 3. How many players were more than the age of 25 during season 2014?

With 2014_Match_Data AS (
	Select Match_ID, Match_Date
    From Matches m
    join season s on m.season_id = s.season_id
    Where s.season_year = 2014
),
2014_Player_Data As (
	Select Player_ID , Max(m.Match_Date) as last_match_date_of_player
	From Player_Match pm
	join 2014_Match_Data m on m.match_id = pm.match_id
	Group By Player_ID
)
Select
	count(*)
From 2014_Player_Data pd
join player p on pd.player_id = p.player_id 
Where timestampdiff(Year, DOB, last_match_date_of_player ) > 25 ;



-- 4. How many matches did RCB win in 2013? 

Select Count(*) as Matches_won_by_RCB_in_2013
From Matches m
where Year(Match_Date) = 2013 AND
Match_winner = 
	(Select team_id 
	From team
	Where team_name = 'Royal Challengers Bangalore'
    )
;


-- 5. List the top 10 players according to their strike rate in the last 4 seasons

WITH RecentSeasons AS (
    SELECT MAX(Season_Year) - 4 AS min_year FROM Season
),
Strike_rate_data AS (
    SELECT bb.Striker,
        ROUND(100 * SUM(bb.Runs_Scored) / COUNT(*), 2) AS Strike_Rate
    FROM ball_by_ball bb
    JOIN Matches m ON m.match_id = bb.match_id
    JOIN Season s1 ON s1.season_id = m.season_id
    JOIN RecentSeasons rs ON s1.Season_Year > rs.min_year
    WHERE NOT EXISTS (
        SELECT 1
        FROM extra_runs er
        WHERE er.match_id = bb.match_id
          AND er.Innings_No = bb.Innings_No
          AND er.Over_Id = bb.Over_Id
          AND er.Ball_Id = bb.Ball_Id
          )
    GROUP BY bb.Striker
)
SELECT
    p.Player_Id, p.Player_Name, s.Strike_Rate
FROM Strike_rate_data s
JOIN player p ON s.Striker = p.player_id
ORDER BY s.Strike_Rate DESC
LIMIT 10;




-- 6. What are the average runs scored by each batsman considering all the seasons?

WITH Player_runs AS (
    SELECT bb.Striker,
        SUM(bb.Runs_Scored) AS total_runs
    FROM ball_by_ball bb
    WHERE NOT EXISTS (
        SELECT 1
        FROM extra_runs er
        WHERE er.match_id = bb.match_id AND er.Innings_No = bb.Innings_No
             AND er.Over_Id = bb.Over_Id AND er.Ball_Id = bb.Ball_Id
	) 
	GROUP BY bb.Striker
),
Out_data As (
	Select Player_out, count(*) as out_count 
    From wicket_taken
	group by Player_out
)
SELECT 
	pr.Striker, p.Player_Name,
	 ROUND(
        CASE WHEN od.out_count IS NULL OR od.out_count = 0 THEN pr.total_runs
            ELSE pr.total_runs / od.out_count
        END, 2) AS Avg_runs
FROM Player_runs pr
left join Out_data od on pr.striker = od.player_out
JOIN player p ON pr.Striker = p.player_id
ORDER BY Avg_runs DESC;



-- 7. What are the average wickets taken by each bowler considering all the seasons?

With bowler_wickets_per_season As (
	Select 
		bb.Bowler, p.Player_Name, m.Season_Id, 
        count(*) as wickets_in_season
	from wicket_taken wt
	Left join out_type ot on wt.kind_out = ot.Out_Id
	Left Join matches m on m.Match_Id = wt.Match_Id
	Left join ball_by_ball bb on 
		bb.match_id = wt.match_id and bb.innings_no = wt.innings_no and
		bb.over_id = wt.over_id and bb.ball_id = wt.ball_id	
	Left Join player p on bb.Bowler = p.Player_Id
	Where ot.Out_Name IN ('caught', 'bowled', 'lbw',
			'stumped', 'caught and bowled', 'hit wicket')
	group by bb.Bowler, p.player_name, m.Season_Id
)
Select 
	Bowler , Player_Name, 
	Round(Avg(wickets_in_season),2) as Avg_wickets_per_season
From bowler_wickets_per_season
Group By Bowler, Player_Name
Order By Avg_wickets_per_season Desc, Bowler Asc;



-- 8. List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average

WITH Player_runs AS (
    SELECT bb.Striker AS player_id,
        SUM(bb.Runs_Scored) AS total_runs
    FROM ball_by_ball bb
    WHERE NOT EXISTS ( SELECT 1
				FROM extra_runs er
				WHERE er.match_id = bb.match_id AND er.Innings_No = bb.Innings_No
				  AND er.Over_Id = bb.Over_Id AND er.Ball_Id = bb.Ball_Id ) 
    GROUP BY bb.Striker ),
Out_data AS ( SELECT Player_out AS player_id, COUNT(*) AS out_count 
				FROM wicket_taken
				GROUP BY Player_out ),
Batting_avg AS ( SELECT 
					pr.player_id,
					ROUND(
						CASE WHEN od.out_count IS NULL OR od.out_count = 0 THEN pr.total_runs
							ELSE pr.total_runs / od.out_count
						END, 2) AS batting_avg
				FROM Player_runs pr
				LEFT JOIN Out_data od ON pr.player_id = od.player_id ),
Overall_batting_avg AS ( SELECT AVG(batting_avg) AS overall_batting_avg
    FROM Batting_avg ),
    
Bowling_wickets AS ( SELECT  bb.Bowler AS player_id, COUNT(*) AS total_wickets
					FROM wicket_taken wt
					JOIN out_type ot ON wt.kind_out = ot.Out_Id
					JOIN ball_by_ball bb ON bb.match_id = wt.match_id 
						AND bb.innings_no = wt.innings_no AND bb.over_id = wt.over_id 
					   AND bb.ball_id = wt.ball_id
					WHERE ot.Out_Name IN ( 'caught', 'bowled', 'lbw',
						'stumped', 'caught and bowled', 'hit wicket' )
					GROUP BY bb.Bowler ),
Overall_wickets_avg AS ( SELECT AVG(total_wickets) AS overall_wickets_avg
						FROM Bowling_wickets )
SELECT p.Player_Id, p.Player_Name, ba.batting_avg, bw.total_wickets
FROM Batting_avg ba
JOIN Bowling_wickets bw ON ba.player_id = bw.player_id
JOIN player p ON p.Player_Id = ba.player_id
CROSS JOIN Overall_batting_avg oba
CROSS JOIN Overall_wickets_avg owa
WHERE 
    ba.batting_avg > oba.overall_batting_avg
    AND bw.total_wickets > owa.overall_wickets_avg
ORDER BY 
    ba.batting_avg DESC, 
    bw.total_wickets DESC;



-- 9. Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

With RCB As (
	Select Team_id
	From Team
	Where Team_Name = 'Royal Challengers Bangalore'
)
Select m.Venue_ID, v.Venue_name, Count(*) As Total_Matches,
	Sum( Case When Match_Winner = (Select Team_ID From RCB) Then 1 Else 0 End ) As Win_Count,
	Sum( Case When Match_Winner != (Select Team_ID From RCB) Then 1 Else 0 End ) As Lose_count
From Matches m
Join  venue v on m.venue_id = v.venue_id
Where Team_1 = (Select Team_ID From RCB) OR
	Team_2 = (Select Team_ID From RCB)
Group By m.Venue_Id, v.Venue_name;



-- 10. What is the impact of bowling style on wickets taken?

With Bowling_vs_Wickets As (
	Select p.Bowling_skill as Bowling_style_id , bs.Bowling_skill,
		count(*) as No_of_wickets
	From Wicket_taken wt
	join ball_by_ball bb on 
			bb.match_id = wt.match_id and bb.innings_no = wt.innings_no and
			bb.over_id = wt.over_id and bb.ball_id = wt.ball_id	
	Join Player p on bb.Bowler = p.Player_id
	Join bowling_style bs on bs.bowling_id = p.bowling_skill
	Group By p.Bowling_skill , bs.Bowling_skill
)
Select Bowling_style_id, Bowling_skill, No_of_wickets, 
	Round((No_of_wickets *100)/(Sum(No_of_wickets) Over()), 2) as percentage
From Bowling_vs_Wickets
Order by percentage desc;



 -- 11. Write the SQL query to provide a status of whether the performance of the team is better than the 
-- previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 

With Team_Season_Runs_Data As (
	Select bb.Team_Batting as Team_Id, m.Season_Id,
		Sum(coalesce(bb.Runs_Scored,0) + coalesce(er.extra_runs,0)) as Total_runs
	From ball_by_ball bb
	Left Join extra_runs er on
		bb.match_id = er.match_id and
		bb.Innings_No = er.Innings_No and
		bb.Over_Id = er.Over_Id and
		bb.Ball_Id = er.Ball_Id
	Join matches m on bb.Match_Id = m.Match_Id
	Group By bb.Team_Batting, m.Season_Id
) ,
Team_Season_Wickets_Data As (
	Select bb.Team_Bowling as Team_id, m.season_id, 
		count(*) as total_wickets
	From wicket_taken wt
	join ball_by_ball bb on
		bb.match_id = wt.match_id AND 
		bb.innings_no = wt.innings_no AND 
		bb.over_id = wt.over_id AND 
		bb.ball_id = wt.ball_id
	Join matches m on wt.Match_Id = m.Match_Id
	Group By bb.Team_Bowling , m.season_id
),
Comparative_Data As(
	Select tsrd.team_id, t.team_name, s.season_year, 
		tsrd.total_runs, 
        tswd.total_wickets,
        lag(season_year) over(partition by team_id order by season_year) as prev_year,
		lag(tsrd.total_runs) over(partition by team_id order by season_year) as py_total_runs,
		lag(tswd.total_wickets) over(partition by team_id order by season_year) as py_total_wickets
	From Team_Season_Runs_Data tsrd
	Join Team_Season_Wickets_Data tswd on
		tsrd.team_id = tswd.team_id and
		tsrd.season_id = tswd.season_id
	Join Team t on t.team_id = tsrd.team_id
	Join season s on tsrd.season_id = s.season_id
)
Select *,
	Case 
		When (total_runs > py_total_runs) and (total_wickets > py_total_wickets) Then "Improved"
        When (total_runs < py_total_runs) and (total_wickets < py_total_wickets) Then "Decreased"
		When (total_runs = py_total_runs) and (total_wickets = py_total_wickets) Then "No Change"
        Else "Mixed"
	End as Result
From Comparative_Data cd
Where py_total_runs is Not Null and 
	py_total_wickets is Not Null 
    -- And team_id =2
;



-- 12. Can you derive more KPIs for the team strategy?

-- a) Runs per Match (Batting Consistency KPI)
WITH team_runs AS (
    SELECT 
        bb.match_id,
        SUM(COALESCE(bb.runs_scored,0) + COALESCE(er.extra_runs,0)) AS match_runs
    FROM ball_by_ball bb
    JOIN team t ON bb.team_batting = t.team_id
    LEFT JOIN extra_runs er 
        ON bb.match_id = er.match_id
       AND bb.innings_no = er.innings_no
       AND bb.over_id = er.over_id
       AND bb.ball_id = er.ball_id
    WHERE t.team_name = 'Royal Challengers Bangalore'
    GROUP BY bb.match_id
)
SELECT 
    ROUND(AVG(match_runs), 2) AS runs_per_match
FROM team_runs;


-- b) Wickets per Match (Bowling Strength KPI)
WITH team_wickets AS (
    SELECT 
        m.match_id,
        COUNT(*) AS match_wickets
    FROM wicket_taken wt
    JOIN ball_by_ball bb 
        ON wt.match_id = bb.match_id
       AND wt.innings_no = bb.innings_no
       AND wt.over_id = bb.over_id
       AND wt.ball_id = bb.ball_id
    JOIN matches m ON wt.match_id = m.match_id
    JOIN team t ON bb.team_bowling = t.team_id
    WHERE t.team_name = 'Royal Challengers Bangalore'
    GROUP BY m.match_id
)
SELECT 
    ROUND(AVG(match_wickets), 2) AS wickets_per_match
FROM team_wickets;


-- c) Dependency Index (Team Depth KPI)
WITH player_runs AS (
    SELECT 
        bb.striker,
        p.player_name,
        SUM(bb.runs_scored) AS runs
    FROM ball_by_ball bb
    JOIN team t ON bb.team_batting = t.team_id
    JOIN player p ON bb.striker = p.player_id
    WHERE t.team_name = 'Royal Challengers Bangalore'
    GROUP BY bb.striker, p.player_name
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY runs DESC) AS rnk
    FROM player_runs
),
totals AS (
    SELECT SUM(runs) AS team_total_runs
    FROM player_runs
)
SELECT 
    ROUND((SUM(runs) * 100.0) /(Select team_total_runs From totals), 2) AS dependency_index_percentage
FROM ranked
WHERE rnk <= 3;


-- d) Death Overs Efficiency (Clutch KPI)
-- (A) Batting Version 
SELECT 
    ROUND(6*SUM(bb.runs_scored + COALESCE(er.extra_runs,0)) / COUNT(*), 2) AS death_overs_run_rate
FROM ball_by_ball bb
JOIN team t ON bb.team_batting = t.team_id
LEFT JOIN extra_runs er 
    ON bb.match_id = er.match_id
   AND bb.innings_no = er.innings_no
   AND bb.over_id = er.over_id
   AND bb.ball_id = er.ball_id
WHERE t.team_name = 'Royal Challengers Bangalore'
  AND bb.over_id BETWEEN 16 AND 20;

-- (B) Bowling Version (Wickets in Death Overs)
With RCB_death_over_wickets As (
	SELECT bb.match_id,
		COUNT(*) AS no_of_wickets
	FROM wicket_taken wt
	JOIN ball_by_ball bb 
		ON wt.match_id = bb.match_id
	   AND wt.innings_no = bb.innings_no
	   AND wt.over_id = bb.over_id
	   AND wt.ball_id = bb.ball_id
	JOIN team t ON bb.team_bowling = t.team_id
	WHERE t.team_name = 'Royal Challengers Bangalore'
	  AND bb.over_id BETWEEN 16 AND 20
	Group by bb.match_id
)
Select Round(Avg(no_of_wickets),2) as Avg_death_over_wickets
From RCB_death_over_wickets ;


-- e) Net Impact Score (Overall Strength KPI)

WITH team_runs AS (
    SELECT 
        t.team_id,
        t.team_name,
        SUM(COALESCE(bb.runs_scored,0) + COALESCE(er.extra_runs,0)) AS total_runs
    FROM team t
    JOIN ball_by_ball bb ON t.team_id = bb.team_batting
    LEFT JOIN extra_runs er 
        ON bb.match_id = er.match_id
       AND bb.innings_no = er.innings_no
       AND bb.over_id = er.over_id
       AND bb.ball_id = er.ball_id
    GROUP BY t.team_id, t.team_name
),
team_wickets AS (
    SELECT 
        t.team_id,
        t.team_name,
        COUNT(*) AS total_wickets
    FROM wicket_taken wt
    JOIN ball_by_ball bb 
        ON wt.match_id = bb.match_id
       AND wt.innings_no = bb.innings_no
       AND wt.over_id = bb.over_id
       AND wt.ball_id = bb.ball_id
    JOIN team t ON bb.team_bowling = t.team_id
    GROUP BY t.team_id, t.team_name
),
combined AS (
    SELECT 
        r.team_id,
        r.team_name,
        r.total_runs,
        w.total_wickets
    FROM team_runs r
    JOIN team_wickets w ON r.team_id = w.team_id
),
league_avg AS (
    SELECT 
        AVG(total_runs) AS avg_runs,
        AVG(total_wickets) AS avg_wickets
    FROM combined
)
SELECT 
    c.team_name,
    ROUND(
        (c.total_runs / la.avg_runs) + 
        (c.total_wickets / la.avg_wickets),
        2
    ) AS net_impact_score
FROM combined c
CROSS JOIN league_avg la
WHERE c.team_name = 'Royal Challengers Bangalore';



-- 13) Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank them according to the average value.

With Bowler_Venue_Data As (
	Select
		v.venue_name , p.player_name,
		count(*) as no_of_wickets,
		count(distinct m.match_id) as no_of_matches,
		Round(1.0*count(*)/count(distinct m.match_id) ,2) as Avg_wickets_taken
	From wicket_taken wt
	Join ball_by_ball bb on
		bb.Match_Id = wt.Match_Id and
		bb.Innings_No = wt.Innings_No and
		bb.Over_Id = wt.Over_Id and
		bb.Ball_Id = wt.Ball_Id
	Join matches m on m.Match_Id = wt.Match_Id
	Join Venue v on v.venue_id = m.Venue_Id
	Join Player p on bb.bowler = p.player_id
	Join out_type ot on ot.out_id = wt.kind_out
	Where ot.Out_Name IN ('caught', 'bowled', 'lbw',
				'stumped', 'caught and bowled', 'hit wicket')
	Group By p.player_id, p.player_name, v.venue_id, v.venue_name
),
Ranked_Data As (
	Select *,
        Dense_Rank() Over(Partition By Venue_name Order by Avg_wickets_taken Desc) as Rnk
	From Bowler_Venue_Data
    Where no_of_matches >= 5
)
Select * 
From Ranked_Data
Order by Venue_Name, Rnk ;



-- 14) Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)

-- Batting Performers

WITH season_runs AS (
    SELECT 
        bb.striker AS player_id,
        p.player_name,
        s.season_year,
        SUM(bb.runs_scored) AS season_runs
    FROM ball_by_ball bb
    JOIN matches m ON bb.match_id = m.match_id
    JOIN season s ON m.season_id = s.season_id
    JOIN player p ON bb.striker = p.player_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM extra_runs er
        WHERE er.match_id = bb.match_id
          AND er.Innings_No = bb.Innings_No
          AND er.Over_Id = bb.Over_Id
          AND er.Ball_Id = bb.Ball_Id
          )
    GROUP BY bb.striker, p.player_name, s.season_year
)
SELECT 
	player_id,
	player_name,
	ROUND(AVG(season_runs), 2) AS avg_runs
	-- ROUND(STDDEV(season_runs), 2) AS std_dev_runs
FROM season_runs
GROUP BY player_id, player_name
Having AVG(season_runs) > 100
ORDER BY avg_runs DESC;


-- Bowling Performers

WITH season_wickets AS (
    SELECT 
        bb.bowler AS player_id,
        p.player_name,
        s.season_year,
        COUNT(*) AS season_wickets
    FROM wicket_taken wt
    JOIN ball_by_ball bb 
        ON wt.match_id = bb.match_id
       AND wt.innings_no = bb.innings_no
       AND wt.over_id = bb.over_id
       AND wt.ball_id = bb.ball_id
    JOIN out_type ot ON wt.kind_out = ot.out_id
    JOIN matches m ON wt.match_id = m.match_id
    JOIN season s ON m.season_id = s.season_id
    JOIN player p ON bb.bowler = p.player_id
    WHERE ot.out_name IN (
        'caught', 'bowled', 'lbw',
        'stumped', 'caught and bowled', 'hit wicket'
    )
    GROUP BY bb.bowler, p.player_name, s.season_year
)
SELECT 
	player_id,
	player_name,
	ROUND(AVG(season_wickets), 2) AS avg_wickets
FROM season_wickets
GROUP BY player_id, player_name
Having AVG(season_wickets) >=10
ORDER BY avg_wickets DESC;

 
 
 -- 15) Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 
 
 -- Bowlers Performance with Venue
 
 WITH Bowler_Venue_Data AS (
    SELECT
        bb.bowler AS player_id,
        p.player_name,
        v.venue_id,
        v.venue_name,
        COUNT(DISTINCT m.match_id) AS no_of_matches,
        COUNT(*) AS total_wickets,
        ROUND(COUNT(*) / COUNT(DISTINCT m.match_id), 2) AS avg_wickets_per_match
    FROM wicket_taken wt
    JOIN ball_by_ball bb 
        ON bb.match_id = wt.match_id
       AND bb.innings_no = wt.innings_no
       AND bb.over_id = wt.over_id
       AND bb.ball_id = wt.ball_id
    JOIN matches m ON m.match_id = wt.match_id
    JOIN venue v ON v.venue_id = m.venue_id
    JOIN player p ON bb.bowler = p.player_id
    JOIN out_type ot ON ot.out_id = wt.kind_out
    WHERE ot.out_name IN (
        'caught', 'bowled', 'lbw',
        'stumped', 'caught and bowled', 'hit wicket'
    )
    GROUP BY bb.bowler, p.player_name, v.venue_id, v.venue_name
),
Overall_Avg AS (
    SELECT
        player_id,
        player_name,
        SUM(total_wickets) / SUM(no_of_matches) AS overall_avg_wickets
    FROM Bowler_Venue_Data
    GROUP BY player_id, player_name
),
Venue_Impact AS (
    SELECT
        bvd.*,
        oa.overall_avg_wickets,
        ROUND(bvd.avg_wickets_per_match - oa.overall_avg_wickets, 2) AS dependency_score
    FROM Bowler_Venue_Data bvd
    JOIN Overall_Avg oa 
        ON bvd.player_id = oa.player_id
	Where no_of_matches >= 5
),
Ranked AS (
    SELECT *,
           DENSE_RANK() OVER (
               PARTITION BY player_id 
               ORDER BY dependency_score DESC
           ) AS rnk
    FROM Venue_Impact
)
SELECT *
FROM Ranked
WHERE rnk = 1
  AND dependency_score > 0
ORDER BY dependency_score DESC;


-- Batsman And Venue scenario

WITH Batsman_Venue_Data AS (
    SELECT 
        bb.striker AS player_id,
        p.player_name,
        v.venue_id,
        v.venue_name,
        COUNT(DISTINCT bb.match_id) AS no_of_matches,
        SUM(bb.runs_scored) AS total_runs,
        ROUND(SUM(bb.runs_scored) / COUNT(DISTINCT bb.match_id), 2) AS avg_runs_per_match
    FROM ball_by_ball bb
    JOIN matches m ON bb.match_id = m.match_id
    JOIN venue v ON v.venue_id = m.venue_id
    JOIN player p ON p.player_id = bb.striker
    WHERE NOT EXISTS (
        SELECT 1
        FROM extra_runs er
        WHERE er.match_id = bb.match_id
          AND er.innings_no = bb.innings_no
          AND er.over_id = bb.over_id
          AND er.ball_id = bb.ball_id
    )
    GROUP BY bb.striker, p.player_name, v.venue_id, v.venue_name
),
Overall_Avg AS (
    SELECT 
        player_id,
        player_name,
        SUM(total_runs) / SUM(no_of_matches) AS overall_avg_runs
    FROM Batsman_Venue_Data
    GROUP BY player_id, player_name
),
Venue_Impact AS (
    SELECT 
        bvd.*,
        oa.overall_avg_runs,
        ROUND(bvd.avg_runs_per_match - oa.overall_avg_runs, 2) AS dependency_score
    FROM Batsman_Venue_Data bvd
    JOIN Overall_Avg oa 
        ON bvd.player_id = oa.player_id
	Where no_of_matches >= 5
),
Ranked AS (
    SELECT *,
           DENSE_RANK() OVER (
               PARTITION BY player_id 
               ORDER BY dependency_score DESC
           ) AS rnk
    FROM Venue_Impact
)
SELECT *
FROM Ranked
WHERE rnk = 1
  AND dependency_score > 0
ORDER BY dependency_score DESC;


-- /////////////////////////////////////// SUBJECTIVE QUESTIONS //////////////////////////////////////////////////////////////////

-- 1) How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?

Select 
	Round(100.0*sum(case when match_winner = toss_winner then 1 else 0 end)
			/ count(match_id),2) as win_percentage
From Matches;


CREATE OR REPLACE VIEW vw_toss_base AS
SELECT
    m.match_id, m.venue_id, m.toss_winner, m.match_winner, m.toss_decide,
    /* Core flags */
    CASE WHEN m.toss_winner = m.match_winner THEN 1 ELSE 0 END AS toss_win_match,
    CASE WHEN m.toss_decide = 1 THEN 1 ELSE 0 END AS chose_field,
    CASE WHEN m.toss_decide = 2 THEN 1 ELSE 0 END AS chose_bat,
    CASE WHEN m.toss_decide = 1 AND m.toss_winner = m.match_winner THEN 1 ELSE 0 END AS field_and_win,
    CASE WHEN m.toss_decide = 2 AND m.toss_winner = m.match_winner THEN 1 ELSE 0 END AS bat_and_win
FROM Matches m;


-- Query to see if winning toss had any effect on winning in all matches
SELECT
    ROUND(100.0 * SUM(toss_win_match) / COUNT(*), 2) AS toss_win_match_percentage,
    ROUND(100.0 * SUM(chose_field) / COUNT(*), 2) AS field_select_percentage,
    ROUND(100.0 * SUM(chose_bat) / COUNT(*), 2) AS bat_select_percentage,
    ROUND(100.0 * SUM(field_and_win) / NULLIF(SUM(chose_field), 0), 2) AS field_first_win_percentage,
    ROUND(100.0 * SUM(bat_and_win) / NULLIF(SUM(chose_bat), 0), 2) AS bat_first_win_percentage
FROM vw_toss_base;


-- Query to see how toss decisions impacted individual teams that won the toss
SELECT
    tb.toss_winner AS team_id, t.team_name,
    COUNT(*) AS no_of_toss_wins,
    Round(100.0*Sum(toss_win_match)/count(*),2) as toss_win_match_win_percentage,
    ROUND(100.0 * SUM(tb.chose_field) / COUNT(*), 2) AS field_select_percentage,
    ROUND(100.0 * SUM(tb.chose_bat) / COUNT(*), 2) AS bat_select_percentage,
    Coalesce(ROUND(100.0 * SUM(tb.field_and_win) / NULLIF(SUM(tb.chose_field), 0), 2),0) AS field_first_win_percentage,
    Coalesce(ROUND(100.0 * SUM(tb.bat_and_win) / NULLIF(SUM(tb.chose_bat), 0), 2),0) AS bat_first_win_percentage
FROM vw_toss_base tb
JOIN Team t ON t.team_id = tb.toss_winner
GROUP BY tb.toss_winner, t.team_name
ORDER BY toss_win_match_win_percentage desc, t.team_name;


-- Query to see if toss has impact in venue
SELECT
    v.venue_id, v.venue_name,
    COUNT(*) AS no_of_toss_wins,
    Round(100.0*Sum(toss_win_match)/count(*),2) as toss_win_match_win_percentage,
    ROUND(100.0 * SUM(tb.chose_field) / COUNT(*), 2) AS field_select_percentage,
    ROUND(100.0 * SUM(tb.chose_bat) / COUNT(*), 2) AS bat_select_percentage,
    ROUND(100.0 * SUM(tb.field_and_win) / NULLIF(SUM(tb.chose_field), 0), 2) AS field_first_win_percentage,
    ROUND(100.0 * SUM(tb.bat_and_win) / NULLIF(SUM(tb.chose_bat), 0), 2) AS bat_first_win_percentage
FROM vw_toss_base tb
JOIN Venue v ON v.venue_id = tb.venue_id
GROUP BY v.venue_id, v.venue_name
Having count(match_id) >= 10
ORDER BY toss_win_match_win_percentage desc, v.venue_name;




-- 2) Suggest some of the players who would be best fit for the team.

-- Query to find top batsman

With ValidBalls AS (
    SELECT
        bb.match_id, bb.Innings_No, bb.Over_Id,
        bb.Ball_Id, bb.Striker, bb.Runs_Scored
    FROM ball_by_ball bb
    JOIN Matches m ON m.match_id = bb.match_id
    JOIN Season s ON s.season_id = m.season_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM extra_runs er
        WHERE er.match_id  = bb.match_id AND er.Innings_No = bb.Innings_No
          AND er.Over_Id    = bb.Over_Id AND er.Ball_Id    = bb.Ball_Id
    )
),
BattingStats AS (
    SELECT
        Striker,
        SUM(Runs_Scored) AS total_runs,
        COUNT(*) AS balls_faced,
        ROUND(100.0 * SUM(Runs_Scored) / COUNT(*), 2) AS strike_rate
    FROM ValidBalls
    GROUP BY Striker
),
OutData AS (
    SELECT
        Player_out,
        COUNT(*) AS out_count
    FROM wicket_taken
    GROUP BY Player_out
)
SELECT
    p.Player_Id, p.Player_Name, bs.total_runs, bs.strike_rate,
    ROUND(
        CASE
            WHEN od.out_count IS NULL OR od.out_count = 0
            THEN bs.total_runs
            ELSE bs.total_runs / od.out_count 
		END, 2) AS batting_average
FROM BattingStats bs
JOIN player p ON p.Player_Id = bs.Striker
LEFT JOIN OutData od ON od.Player_out = bs.Striker
Having bs.total_runs > 300 and
	batting_average > 30
ORDER BY bs.strike_rate DESC, batting_Average desc ;


-- Query to find top bowlers

WITH LegalBalls AS (
    SELECT bb.match_id, bb.Innings_No,
        bb.Over_Id, bb.Ball_Id, bb.Bowler, bb.Runs_Scored
    FROM ball_by_ball bb
    WHERE NOT EXISTS (
        SELECT 1
        FROM extra_runs er
        WHERE er.match_id   = bb.match_id AND er.Innings_No = bb.Innings_No
          AND er.Over_Id    = bb.Over_Id AND er.Ball_Id    = bb.Ball_Id
    )
),
ExtraRuns AS (
    SELECT
        bb.Bowler,
        SUM(er.Extra_Runs) AS extra_runs_conceded
    FROM extra_runs er
    JOIN ball_by_ball bb ON 
		er.match_id   = bb.match_id AND er.Innings_No = bb.Innings_No AND 
        er.Over_Id    = bb.Over_Id AND er.Ball_Id    = bb.Ball_Id
    GROUP BY bb.Bowler
),
BowlingStats AS (
    SELECT
        lb.Bowler,
        COUNT(*) AS balls_bowled,
        SUM(lb.Runs_Scored) AS runs_off_bat
    FROM LegalBalls lb
    GROUP BY lb.Bowler
),
WicketStats AS (
    SELECT
        lb.Bowler,
        COUNT(*) AS wickets
    FROM wicket_taken wt
    Join LegalBalls lb on 
		lb.match_id = wt.match_id AND lb.Innings_No = wt.Innings_No AND 
        lb.Over_Id    = wt.Over_Id AND lb.Ball_Id    = wt.Ball_Id
    GROUP BY lb.Bowler
)
SELECT
    p.Player_Id,
    p.Player_Name,
    ws.wickets,
    ROUND( (bs.runs_off_bat + COALESCE(er.extra_runs_conceded, 0)) * 6.0 
			/ bs.balls_bowled, 2) AS economy_rate,
    ROUND(
        CASE
            WHEN ws.wickets = 0 OR ws.wickets IS NULL THEN NULL
            ELSE (bs.runs_off_bat + COALESCE(er.extra_runs_conceded, 0))
                 / ws.wickets END, 2 ) AS bowling_average
FROM BowlingStats bs
LEFT JOIN ExtraRuns er ON bs.Bowler = er.Bowler
LEFT JOIN WicketStats ws ON bs.Bowler = ws.Bowler
JOIN player p ON p.Player_Id = bs.Bowler
WHERE
    bs.balls_bowled >= 120       -- minimum workload
    AND ws.wickets >= 20
ORDER BY 
	bowling_average asc, economy_rate ASC , ws.wickets DESC;




-- 4)Which players offer versatility in their skills and can contribute effectively with both bat and ball?

-- View Query to find top batsman

CREATE OR REPLACE VIEW top_batsmen AS (
	With ValidBalls AS (
		SELECT
			bb.match_id, bb.Innings_No, bb.Over_Id,
			bb.Ball_Id, bb.Striker, bb.Runs_Scored
		FROM ball_by_ball bb
		JOIN Matches m ON m.match_id = bb.match_id
		JOIN Season s ON s.season_id = m.season_id
		WHERE NOT EXISTS (
			SELECT 1
			FROM extra_runs er
			WHERE er.match_id  = bb.match_id AND er.Innings_No = bb.Innings_No
			  AND er.Over_Id    = bb.Over_Id AND er.Ball_Id    = bb.Ball_Id
		)
	),
	BattingStats AS (
		SELECT
			Striker,
			SUM(Runs_Scored) AS total_runs,
			COUNT(*) AS balls_faced,
			ROUND(100.0 * SUM(Runs_Scored) / COUNT(*), 2) AS strike_rate
		FROM ValidBalls
		GROUP BY Striker
	),
	OutData AS (
		SELECT
			Player_out,
			COUNT(*) AS out_count
		FROM wicket_taken
		GROUP BY Player_out
	)
	SELECT
		p.Player_Id, p.Player_Name, bs.total_runs, bs.strike_rate,
		ROUND(
			CASE
				WHEN od.out_count IS NULL OR od.out_count = 0
				THEN bs.total_runs
				ELSE bs.total_runs / od.out_count 
			END, 2) AS batting_average
	FROM BattingStats bs
	JOIN player p ON p.Player_Id = bs.Striker
	LEFT JOIN OutData od ON od.Player_out = bs.Striker
	Having bs.total_runs > 200 and
		batting_average > 20
	ORDER BY bs.strike_rate DESC, batting_Average desc 
) ;



-- View Query to find top bowlers

CREATE OR REPLACE VIEW top_bowlers AS (
	WITH LegalBalls AS (
		SELECT bb.match_id, bb.Innings_No,
			bb.Over_Id, bb.Ball_Id, bb.Bowler, bb.Runs_Scored
		FROM ball_by_ball bb
		WHERE NOT EXISTS (
			SELECT 1
			FROM extra_runs er
			WHERE er.match_id   = bb.match_id AND er.Innings_No = bb.Innings_No
			  AND er.Over_Id    = bb.Over_Id AND er.Ball_Id    = bb.Ball_Id
		)
	),
	ExtraRuns AS (
		SELECT
			bb.Bowler,
			SUM(er.Extra_Runs) AS extra_runs_conceded
		FROM extra_runs er
		JOIN ball_by_ball bb ON 
			er.match_id   = bb.match_id AND er.Innings_No = bb.Innings_No AND 
			er.Over_Id    = bb.Over_Id AND er.Ball_Id    = bb.Ball_Id
		GROUP BY bb.Bowler
	),
	BowlingStats AS (
		SELECT
			lb.Bowler,
			COUNT(*) AS balls_bowled,
			SUM(lb.Runs_Scored) AS runs_off_bat
		FROM LegalBalls lb
		GROUP BY lb.Bowler
	),
	WicketStats AS (
		SELECT
			lb.Bowler,
			COUNT(*) AS wickets
		FROM wicket_taken wt
		Join LegalBalls lb on 
			lb.match_id = wt.match_id AND lb.Innings_No = wt.Innings_No AND 
			lb.Over_Id    = wt.Over_Id AND lb.Ball_Id    = wt.Ball_Id
		GROUP BY lb.Bowler
	)
	SELECT
		p.Player_Id,
		p.Player_Name,
		ws.wickets,
		ROUND( (bs.runs_off_bat + COALESCE(er.extra_runs_conceded, 0)) * 6.0 
				/ bs.balls_bowled, 2) AS economy_rate,
		ROUND(
			CASE
				WHEN ws.wickets = 0 OR ws.wickets IS NULL THEN NULL
				ELSE (bs.runs_off_bat + COALESCE(er.extra_runs_conceded, 0))
					 / ws.wickets END, 2 ) AS bowling_average
	FROM BowlingStats bs
	LEFT JOIN ExtraRuns er ON bs.Bowler = er.Bowler
	LEFT JOIN WicketStats ws ON bs.Bowler = ws.Bowler
	JOIN player p ON p.Player_Id = bs.Bowler
	WHERE
		bs.balls_bowled >= 120       -- minimum workload
		AND ws.wickets >= 10
	ORDER BY 
		bowling_average asc, economy_rate ASC , ws.wickets DESC
);


-- Query to find top allropunders

Select bm.*,
	wickets,
    economy_rate,
    bowling_average
From top_batsmen bm
Join top_bowlers bw on bm.Player_ID = bw.Player_ID;



-- 5) Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)

-- Man of Match stats

Select p.player_id, p.player_name,
	count(*) as no_of_mom
From matches m
Join Player p on m.Man_of_the_Match = p.player_id
Group By p.player_id, p.player_name
Having count(*) >= 4
Order By no_of_mom desc;


-- Palyer presence and win percentage stats

SELECT
    p.player_id,
    p.player_name,
    t.team_name,
    COUNT(pm.match_id) AS matches_played,
    SUM(CASE WHEN m.match_winner = t.team_id THEN 1 ELSE 0 END) AS matches_won,
    ROUND(
        100.0 * SUM(CASE WHEN m.match_winner = t.team_id THEN 1 ELSE 0 END)
        / COUNT(pm.match_id), 2
    ) AS win_percentage
FROM player_match pm
JOIN matches m 
    ON pm.match_id = m.match_id
JOIN team t 
    ON pm.team_id = t.team_id
JOIN player p 
    ON pm.player_id = p.player_id
GROUP BY p.player_id, p.player_name, t.team_name
HAVING COUNT(pm.match_id) >= 30
ORDER BY win_percentage DESC;



-- 7) What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies

-- PowerPlay and Death Overs runs

SELECT
    t.Team_Name,
    SUM(CASE WHEN bb.Over_Id BETWEEN 1 AND 6 
			THEN coalesce(Runs_Scored,0) + coalesce(extra_runs,0) ELSE 0 END) AS Powerplay_Runs,
    SUM(CASE WHEN bb.Over_Id BETWEEN 16 AND 20 
			THEN coalesce(Runs_Scored,0) + coalesce(extra_runs,0) ELSE 0 END) AS Death_Over_Runs,
	Round(100.0*SUM(Case When Runs_Scored IN (4,6) or extra_runs in (4,6) 
						Then coalesce(Runs_Scored,0) + coalesce(extra_runs,0) else 0 End )/
							Sum(coalesce(Runs_Scored,0) + coalesce(extra_runs,0)),2) As Boundary_Percentage
FROM ball_by_ball bb
Left Join extra_runs er on
	bb.match_id = er.match_id and
	bb.Innings_No = er.Innings_No and
	bb.Over_Id = er.Over_Id and
	bb.Ball_Id = er.Ball_Id
JOIN team t
    ON bb.Team_Batting = t.Team_Id
GROUP BY t.Team_Name
ORDER BY Powerplay_Runs DESC, Death_Over_Runs DESC, Boundary_Percentage Desc;


-- venue impact for average total runs in a match

WITH MatchRuns AS (
    SELECT
        bb.Match_Id,
        SUM(bb.Runs_Scored) + COALESCE(SUM(er.Extra_Runs), 0) AS Total_Runs
    FROM ball_by_ball bb
    LEFT JOIN extra_runs er ON 
		bb.Match_Id = er.Match_Id AND bb.Innings_No = er.Innings_No
       AND bb.Over_Id = er.Over_Id AND bb.Ball_Id = er.Ball_Id
    GROUP BY bb.Match_Id
)
SELECT
    v.Venue_Name,
    AVG(mr.Total_Runs) AS Avg_Runs_Per_Match,
    COUNT(m.Match_Id) AS Total_Matches
FROM venue v
JOIN matches m ON v.Venue_Id = m.Venue_Id
JOIN MatchRuns mr ON m.Match_Id = mr.Match_Id
GROUP BY v.Venue_Name
ORDER BY Total_Matches DESC, Avg_Runs_Per_Match DESC
LIMIT 10;




-- 8) Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.

-- Home and Away match stats

WITH RCB AS (
    SELECT Team_Id
    FROM Team
    WHERE Team_Name = 'Royal Challengers Bangalore'
),
RCB_Match_Stats AS (
    SELECT
        CASE WHEN v.Venue_Name = 'M Chinnaswamy Stadium' THEN 'Home' ELSE 'Away' END AS Match_Type,
        COUNT(*) AS Total_Matches,
        SUM( CASE WHEN m.Match_Winner = (SELECT Team_Id FROM RCB) THEN 1 ELSE 0 END) AS Win_Count,
        SUM( CASE WHEN m.Match_Winner != (SELECT Team_Id FROM RCB) THEN 1 ELSE 0 END) AS Lose_Count
    FROM Matches m
    JOIN Venue v ON m.Venue_Id = v.Venue_Id
    WHERE m.Team_1 = (SELECT Team_Id FROM RCB) OR m.Team_2 = (SELECT Team_Id FROM RCB)
    GROUP BY
       (CASE WHEN v.Venue_Name = 'M Chinnaswamy Stadium' THEN 'Home' ELSE 'Away' END )
)
SELECT
    Match_Type, Total_Matches, Win_Count, Lose_Count,
    ROUND(100.0 * Win_Count / Total_Matches, 2) AS Win_Percentage,
    ROUND(100.0 * Lose_Count / Total_Matches, 2) AS Lose_Percentage
FROM RCB_Match_Stats;


-- Bat First, Bowl_first stats

WITH RCB AS (
    SELECT Team_Id
    FROM Team
    WHERE Team_Name = 'Royal Challengers Bangalore'
),
RCB_Chinnaswamy_Matches AS (
    SELECT
        m.Match_Id,
        CASE WHEN (m.Toss_Winner = (SELECT Team_Id FROM RCB) AND m.Toss_Decide = 2)
                   OR
                (m.Toss_Winner != (SELECT Team_Id FROM RCB) AND m.Toss_Decide = 1)
            THEN 'Bat First' ELSE 'Bowl First' END AS RCB_Innings_Type,
        m.Match_Winner
    FROM Matches m
    JOIN Venue v ON m.Venue_Id = v.Venue_Id
    WHERE v.Venue_Name = 'M Chinnaswamy Stadium' AND (
            m.Team_1 = (SELECT Team_Id FROM RCB)
            OR m.Team_2 = (SELECT Team_Id FROM RCB)
        )
),
RCB_Innings_Summary As (
	SELECT
		RCB_Innings_Type,
		count(*) as no_of_matches,
		Sum(Case When Match_Winner = (SELECT Team_Id FROM RCB) Then 1 Else 0 End) AS Matches_Won,
		Sum(Case When Match_Winner <> (SELECT Team_Id FROM RCB) Then 1 Else 0 End) AS Matches_Lost
	FROM RCB_Chinnaswamy_Matches
	GROUP BY RCB_Innings_Type
)
Select
	*,
    Round(100.0*Matches_won/no_of_Matches,2) as win_percentage ,
    Round(100.0*Matches_Lost/no_of_Matches,2) as lose_percentage
from RCB_Innings_Summary;



-- Player performances in Home ground

-- a) batsman

WITH Strike_rate_data AS (
    SELECT bb.Striker,
		Count(distinct m.match_id) as No_of_matches,
		SUM(bb.Runs_Scored) as Total_Player_Runs,
        ROUND(100 * SUM(bb.Runs_Scored) / COUNT(*), 2) AS Strike_Rate
    FROM ball_by_ball bb
    JOIN Matches m ON m.match_id = bb.match_id
    JOIN Season s1 ON s1.season_id = m.season_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM extra_runs er
        WHERE er.match_id = bb.match_id
          AND er.Innings_No = bb.Innings_No
          AND er.Over_Id = bb.Over_Id
          AND er.Ball_Id = bb.Ball_Id
          )
		AND m.venue_id = 1
    GROUP BY bb.Striker
)
SELECT
    p.Player_Id, p.Player_Name, 
    s.no_of_matches, s.Total_Player_Runs, s.Strike_Rate
FROM Strike_rate_data s
JOIN player p ON s.Striker = p.player_id
Where Total_Player_Runs >= 100 AND Strike_rate >=100
ORDER BY s.Strike_Rate DESC, Total_Player_Runs Desc;


-- b) bowler stats in home ground

WITH Bowler_Venue_Data AS (
    SELECT
        bb.bowler AS player_id,
        p.player_name,
        v.venue_id,
        v.venue_name,
        COUNT(DISTINCT m.match_id) AS no_of_matches,
        COUNT(*) AS total_wickets,
        ROUND(COUNT(*) / COUNT(DISTINCT m.match_id), 2) AS avg_wickets_per_match
    FROM wicket_taken wt
    JOIN ball_by_ball bb 
        ON bb.match_id = wt.match_id
       AND bb.innings_no = wt.innings_no
       AND bb.over_id = wt.over_id
       AND bb.ball_id = wt.ball_id
    JOIN matches m ON m.match_id = wt.match_id
    JOIN venue v ON v.venue_id = m.venue_id
    JOIN player p ON bb.bowler = p.player_id
    JOIN out_type ot ON ot.out_id = wt.kind_out
    WHERE ot.out_name IN (
        'caught', 'bowled', 'lbw',
        'stumped', 'caught and bowled', 'hit wicket'
    )
    GROUP BY bb.bowler, p.player_name, v.venue_id, v.venue_name
),
Overall_Avg AS (
    SELECT
        player_id,
        player_name,
        SUM(total_wickets) / SUM(no_of_matches) AS overall_avg_wickets
    FROM Bowler_Venue_Data
    GROUP BY player_id, player_name
),
Venue_Impact AS (
    SELECT
        bvd.*,
        oa.overall_avg_wickets,
        ROUND(bvd.avg_wickets_per_match - oa.overall_avg_wickets, 2) AS dependency_score
    FROM Bowler_Venue_Data bvd
    JOIN Overall_Avg oa 
        ON bvd.player_id = oa.player_id
	Where no_of_matches >= 3
)
SELECT *
FROM Venue_Impact
WHERE dependency_score > 0 AND venue_name = "M Chinnaswamy Stadium"
ORDER BY dependency_score DESC;



-- 9) Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.

-- Season wise total matches played win and loss percentages

Select 
	season_id, count(*) as no_of_matches,
    Sum(Case when match_winner = 2 then 1 else 0 end) as no_of_wins,
    Sum(Case when match_winner <> 2 then 1 else 0 end) as no_of_loss,
    Round(100.0*Sum( Case when match_winner = 2 then 1 else 0 end)/Count(*),2) as win_percentage,
    Round(100.0*Sum( Case when match_winner <> 2 then 1 else 0 end)/Count(*),2) as loss_percentage
From Matches
Where Team_1 = 2 or Team_2 = 2     -- team_id = 2 is for RCB in 'Team' table
group by season_id;



--   Created View to get play off_matches

CREATE OR REPLACE VIEW play_off_matches As (
With ranked_matches As(
	Select
		season_id, Match_id , venue_id, Team_1, Team_2, Toss_winner, 
        toss_name as chosen, match_winner, win_margin, w.win_type,
		Row_Number() Over(Partition By season_id Order by Match_Date Desc) as rnk
	From Matches m
	join toss_decision t on m.toss_decide = t.toss_id
	Join win_by w on m.win_type = w.win_id
)
Select *,
Case When rnk = 1 Then 'Finals'
	 When rnk = 2 Then 'Qualifier 2'
	 when rnk = 3 Then 'Eliminator'
	 when rnk = 4 Then 'Qualifier 1'
Else 'leauge_match' End as match_type
From ranked_matches
Where rnk <=4 
);
Select * From play_off_matches;



-- Matches Data where RCB qualified for Play offs

CREATE OR REPLACE VIEW RCB_in_Play_offs AS (
	With RCB AS (
		SELECT Team_Id
		FROM Team
		WHERE Team_Name = 'Royal Challengers Bangalore'
	)
	Select *
	From play_off_matches
	Where team_1 = (Select team_id from RCB) or team_2 = (Select team_id from RCB)
);
Select * From RCB_in_Play_offs;



-- Individual Match Score Table 

CREATE OR REPLACE VIEW Match_Stats AS (
	WITH Player_Runs As (
		Select
			bb.match_id, Team_Batting, Striker, p.player_name, Sum(runs_scored)  as player_runs
		From Ball_By_Ball bb
		Join Player p on p.player_id = bb.striker
		Group By bb.match_id, Team_Batting, Striker, p.player_name
		Order By bb.match_id, Team_Batting, Striker, p.player_name
	),
	Team_Total As (
		Select
			bb.match_id, Team_Batting,
			SUM(bb.Runs_Scored) + COALESCE(SUM(er.Extra_Runs), 0) AS Team_Total_Runs
		From Ball_By_Ball bb
		Left Join extra_runs er ON 
				bb.Match_Id = er.Match_Id AND bb.Innings_No = er.Innings_No
			   AND bb.Over_Id = er.Over_Id AND bb.Ball_Id = er.Ball_Id
		Group By bb.match_id, Team_Batting
	)
	Select
		pr.match_id, pr.team_batting, pr.striker, player_name, player_runs, team_total_runs,
		Round(100.0*player_runs / team_total_runs , 2) as player_perc_team_total
	From Player_runs pr
	Join Team_Total tt on tt.match_id = pr.match_id and tt.team_batting = pr.team_batting
	Order By pr.match_id, pr.team_batting, player_runs desc
);



-- Season 8 Losing match stats

Select 
	match_id, team_batting, team_name, striker, player_name, 
    player_runs, team_total_runs, player_perc_team_total
From Match_stats ms
Join team t on ms.team_batting = t.team_id
Where Match_id = 829826
Order By match_id, team_batting, player_runs desc;



-- season 9 Losing match stats

Select 
	match_id, team_batting, team_name, striker, player_name, 
	player_runs, team_total_runs, player_perc_team_total
From Match_stats ms
Join team t on ms.team_batting = t.team_id
Where Match_id = 981024
Order By match_id, team_batting, player_runs desc;



-- 11) In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

UPDATE Team
SET Opponent_Team = 'Delhi_Daredevils'
WHERE Opponent_Team = 'Delhi_Capitals';


-- /////////////////////////////////////////// Thank You ////////////////////////////////////////////////////////////////////




