-- Find co-play within a timestamp burst on one game, table, shoe and hand.
CREATE TEMP TABLE plays AS
WITH timed AS (
    SELECT member, game, tableNO, shoe_ID, shoe_hand,
           make_timestamp(epoch_us(min_time_stamp)) AS wager_at,
           bet, wl, prop_bet, primary_bet,
           lag(make_timestamp(epoch_us(min_time_stamp))) OVER hand_key AS previous
    FROM wagers
    WHERE game IN ('traditional', 'non_com', 'fab4', 'super_98', 'lucky_sq', 'dragon_tiger')
      AND member IS NOT NULL AND tableNO IS NOT NULL
      AND shoe_ID IS NOT NULL AND shoe_hand IS NOT NULL AND min_time_stamp IS NOT NULL
    WINDOW hand_key AS (PARTITION BY game, tableNO, shoe_ID, shoe_hand ORDER BY min_time_stamp)
), bursts AS (
    SELECT *, sum(CASE WHEN previous IS NULL OR wager_at - previous > INTERVAL '60 seconds'
                       THEN 1 ELSE 0 END) OVER hand_key AS burst
    FROM timed
    WINDOW hand_key AS (PARTITION BY game, tableNO, shoe_ID, shoe_hand ORDER BY wager_at)
), numbered AS (
    SELECT *, dense_rank() OVER (ORDER BY game, tableNO, shoe_ID, shoe_hand, burst) AS round_id,
           min(wager_at) OVER (PARTITION BY game, tableNO, shoe_ID, shoe_hand, burst) AS first_wager
    FROM bursts
)
SELECT round_id, member, bet, wl, first_wager,
       primary_bet IN ('Banker', 'Dragon') AS banker_side,
       round(20 * ln(bet))::INTEGER AS stake_bucket,
       epoch(wager_at - first_wager) AS delay_seconds
FROM numbered
WHERE ((game = 'dragon_tiger' AND primary_bet IN ('Dragon', 'Tiger'))
       OR (game <> 'dragon_tiger' AND primary_bet IN ('Banker', 'Player')))
  AND prop_bet = 0 AND bet > 0 AND isfinite(bet)
QUALIFY count(*) OVER (PARTITION BY round_id, member) = 1;

CREATE TEMP TABLE candidates AS
SELECT least(a.member, b.member) AS account_a, greatest(a.member, b.member) AS account_b
FROM plays a JOIN plays b USING (round_id, stake_bucket)
WHERE a.banker_side AND NOT b.banker_side
GROUP BY ALL HAVING count(*) >= coalesce(getvariable('min_mirrors')::INTEGER, 30);

CREATE TEMP TABLE shared AS
SELECT c.account_a, c.account_b, a.round_id, a.first_wager,
       a.banker_side AS side_a, b.banker_side AS side_b,
       a.stake_bucket AS stake_a, b.stake_bucket AS stake_b,
       a.delay_seconds AS delay_a, b.delay_seconds AS delay_b,
       a.bet + b.bet AS turnover, a.wl + b.wl AS house_win
FROM candidates c
JOIN plays a ON a.member = c.account_a
JOIN plays b ON b.member = c.account_b AND b.round_id = a.round_id;

CREATE TEMP TABLE pair_metrics AS
WITH sequenced AS (
    SELECT *, lead(delay_b) OVER pair_order AS next_delay_b,
              lead(delay_a) OVER pair_order AS next_delay_a
    FROM shared
    WINDOW pair_order AS (PARTITION BY account_a, account_b ORDER BY first_wager, round_id)
), pairs AS (
    SELECT account_a, account_b, count(*) AS shared_rounds,
           count(*) FILTER (WHERE side_a <> side_b) AS opposite,
           count(*) FILTER (WHERE side_a <> side_b AND stake_a = stake_b) AS mirrored,
           avg(side_a::INT) AS share_a, avg(side_b::INT) AS share_b,
           avg((stake_a = stake_b)::INT) AS stake_match,
           avg((abs(delay_a - delay_b) <= 2)::INT) AS close_in_time,
           (avg((abs(delay_a - next_delay_b) <= 2)::INT)
            + avg((abs(delay_b - next_delay_a) <= 2)::INT)) / 2 AS shifted_close,
           sum(turnover) FILTER (WHERE side_a <> side_b AND stake_a = stake_b) AS mirror_turnover,
           sum(house_win) FILTER (WHERE side_a <> side_b AND stake_a = stake_b) AS mirror_house_win
    FROM sequenced GROUP BY account_a, account_b
), a AS (
    SELECT account_a, account_b, stake_a AS bucket, count(*) AS uses
    FROM shared GROUP BY ALL
), b AS (
    SELECT account_a, account_b, stake_b AS bucket, count(*) AS uses
    FROM shared GROUP BY ALL
), expected_stake AS (
    SELECT account_a, account_b, sum(a.uses * b.uses) AS match_product
    FROM a JOIN b USING (account_a, account_b, bucket) GROUP BY account_a, account_b
), activity AS (
    SELECT member, count(*) AS hands FROM wagers GROUP BY member
)
SELECT p.*, share_a * (1 - share_b) + (1 - share_a) * share_b AS expected_opposite,
       stake_match * shared_rounds * shared_rounds / nullif(match_product, 0) AS stake_lift,
       close_in_time / nullif(shifted_close, 0) AS timing_lift,
       shared_rounds * 1.0 / least(a.hands, b.hands) AS co_presence
FROM pairs p
LEFT JOIN expected_stake USING (account_a, account_b)
JOIN activity a ON a.member = p.account_a
JOIN activity b ON b.member = p.account_b;
