DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'unique_subscription_entry'
    ) THEN
        -- Add the unique constraint if it doesn't exist
        ALTER TABLE churn_rate_by_day
        ADD CONSTRAINT unique_subscription_entry UNIQUE (date, metro_id, utm_source, utm_medium, utm_campaign);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS churn_rate_by_day (
    date DATE,
    metro_id TEXT,
    utm_source TEXT,
    utm_medium TEXT,
    utm_campaign TEXT,
    involuntary_churn INTEGER,
    voluntary_churn INTEGER,
    base_churn INTEGER
);

DO $$
DECLARE
    date_pointer DATE;
    start_date DATE;
    end_date DATE;
BEGIN
    SELECT MIN(DATE(created_at)) INTO start_date FROM api_subscriptions;
    end_date := (SELECT MAX(DATE(created_at)) FROM api_subscriptions) - INTERVAL '1 day';

    date_pointer := start_date;

    WHILE date_pointer <= end_date LOOP
        start_date := date_pointer - INTERVAL '30 days';

        INSERT INTO churn_rate_by_day (date, metro_id, utm_source, utm_medium, utm_campaign, involuntary_churn, voluntary_churn, base_churn)
        WITH base_data AS (
            SELECT
                date_pointer AS date,
                sd.metro_id,
                sd.utm_source,
                sd.utm_medium,
                sd.utm_campaign,
                (COALESCE(SUM(CASE WHEN sd.status = 'Unpaid' THEN sd.subscription_count ELSE 0 END), 0)
                 - COALESCE((SELECT SUM(subscription_count) FROM subscriptions_by_day 
                             WHERE status = 'Unpaid' AND date = start_date AND sd.metro_id = subscriptions_by_day.metro_id 
                               AND sd.utm_source = subscriptions_by_day.utm_source 
                               AND sd.utm_medium = subscriptions_by_day.utm_medium 
                               AND sd.utm_campaign = subscriptions_by_day.utm_campaign), 0)) AS involuntary_churn,
                (COALESCE(SUM(CASE WHEN sd.status = 'Canceled' THEN sd.subscription_count ELSE 0 END), 0)
                 - COALESCE((SELECT SUM(subscription_count) FROM subscriptions_by_day 
                             WHERE status = 'Canceled' AND date = start_date AND sd.metro_id = subscriptions_by_day.metro_id 
                               AND sd.utm_source = subscriptions_by_day.utm_source 
                               AND sd.utm_medium = subscriptions_by_day.utm_medium 
                               AND sd.utm_campaign = subscriptions_by_day.utm_campaign), 0)) AS voluntary_churn,
                (
                    COALESCE((SELECT SUM(subscription_count) FROM subscriptions_by_day 
                              WHERE status = 'Active' AND date = start_date AND 
                                    sd.metro_id = subscriptions_by_day.metro_id AND 
                                    sd.utm_source = subscriptions_by_day.utm_source AND 
                                    sd.utm_medium = subscriptions_by_day.utm_medium AND 
                                    sd.utm_campaign = subscriptions_by_day.utm_campaign), 0)
                    +
                    (COALESCE((SELECT SUM(subscription_count) FROM subscriptions_by_day 
                               WHERE status = 'Active' AND date = date_pointer AND 
                                     sd.metro_id = subscriptions_by_day.metro_id AND 
                                     sd.utm_source = subscriptions_by_day.utm_source AND 
                                     sd.utm_medium = subscriptions_by_day.utm_medium AND 
                                     sd.utm_campaign = subscriptions_by_day.utm_campaign), 0)
                    -
                    COALESCE((SELECT SUM(subscription_count) FROM subscriptions_by_day 
                              WHERE status = 'Active' AND date = start_date AND 
                                    sd.metro_id = subscriptions_by_day.metro_id AND 
                                    sd.utm_source = subscriptions_by_day.utm_source AND 
                                    sd.utm_medium = subscriptions_by_day.utm_medium AND 
                                    sd.utm_campaign = subscriptions_by_day.utm_campaign), 0))
                ) AS base_churn
            FROM
                subscriptions_by_day sd
            WHERE
                sd.date = date_pointer
            GROUP BY
                date_pointer, sd.metro_id, sd.utm_source, sd.utm_medium, sd.utm_campaign
        )
        SELECT * FROM base_data
	ON CONFLICT (date, metro_id, utm_source, utm_medium, utm_campaign)
        DO UPDATE SET
            involuntary_churn = EXCLUDED.involuntary_churn,
            voluntary_churn = EXCLUDED.voluntary_churn,
            base_churn = EXCLUDED.base_churn;

        date_pointer := date_pointer + INTERVAL '1 day';
    END LOOP;
END $$;
