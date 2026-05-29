USE [capacity-optimization]
CREATE TABLE locations (
    location_id INT PRIMARY KEY,
    location_name VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(50)
);

CREATE TABLE providers (
    provider_id INT PRIMARY KEY,
    provider_name VARCHAR(100),
    specialty VARCHAR(100),
    location_id INT,
    fte DECIMAL(3,2),
    weekly_available_hours INT,
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

CREATE TABLE patients (
    patient_id INT PRIMARY KEY,
    age_group VARCHAR(50),
    insurance_type VARCHAR(50),
    language_preference VARCHAR(50),
    risk_level VARCHAR(50)
);

CREATE TABLE provider_availability (
    availability_id INT PRIMARY KEY,
    provider_id INT,
    availability_date DATE,
    available_minutes INT,
    FOREIGN KEY (provider_id) REFERENCES providers(provider_id)
);

CREATE TABLE appointments (
    appointment_id INT PRIMARY KEY,
    patient_id INT,
    provider_id INT,
    appointment_date DATE,
    scheduled_date DATE,
    appointment_type VARCHAR(100),
    status VARCHAR(50),
    duration_minutes INT,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (provider_id) REFERENCES providers(provider_id)
);

CREATE TABLE referrals (
    referral_id INT PRIMARY KEY,
    patient_id INT,
    specialty VARCHAR(100),
    location_id INT,
    referral_date DATE,
    priority_level VARCHAR(50),
    appointment_needed_by DATE,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

USE [capacity-optimization];
GO

BULK INSERT locations
FROM 'C:\Users\christopherfontes\OneDrive\Desktop\capacity-optimization\locations.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

BULK INSERT providers
FROM 'C:\Users\christopherfontes\OneDrive\Desktop\capacity-optimization\providers.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT patients
FROM 'C:\Users\christopherfontes\OneDrive\Desktop\capacity-optimization\patients.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT provider_availability
FROM 'C:\Users\christopherfontes\OneDrive\Desktop\capacity-optimization\provider_availability.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT appointments
FROM 'C:\Users\christopherfontes\OneDrive\Desktop\capacity-optimization\appointments.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT referrals
FROM 'C:\Users\christopherfontes\OneDrive\Desktop\capacity-optimization\referrals.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

SELECT 'locations' AS table_name, COUNT(*) AS row_count FROM locations
UNION ALL
SELECT 'providers', COUNT(*) FROM providers
UNION ALL
SELECT 'patients', COUNT(*) FROM patients
UNION ALL
SELECT 'provider_availability', COUNT(*) FROM provider_availability
UNION ALL
SELECT 'appointments', COUNT(*) FROM appointments
UNION ALL
SELECT 'referrals', COUNT(*) FROM referrals;

WITH booked_time AS (
    SELECT
        provider_id,
        appointment_date,
        SUM(duration_minutes) AS booked_minutes
    FROM appointments
    WHERE status = 'Completed'
    GROUP BY
        provider_id,
        appointment_date
),

capacity AS (
    SELECT
        provider_id,
        availability_date,
        SUM(available_minutes) AS available_minutes
    FROM provider_availability
    GROUP BY
        provider_id,
        availability_date
)

SELECT
    p.provider_name,
    p.specialty,
    l.location_name,

    SUM(c.available_minutes)
        AS total_available_minutes,

    SUM(COALESCE(b.booked_minutes, 0))
        AS total_booked_minutes,

    SUM(c.available_minutes)
        - SUM(COALESCE(b.booked_minutes, 0))
        AS unused_minutes,

    CONVERT(
        DECIMAL(5,2),
        ROUND(
            (
                SUM(COALESCE(b.booked_minutes, 0)) * 100.0
            ) /
            NULLIF(
                SUM(c.available_minutes),
                0
            ),
            2
        )
    ) AS utilization_rate

FROM capacity c

LEFT JOIN booked_time b
    ON c.provider_id = b.provider_id
    AND c.availability_date = b.appointment_date

JOIN providers p
    ON c.provider_id = p.provider_id

JOIN locations l
    ON p.location_id = l.location_id

GROUP BY
    p.provider_name,
    p.specialty,
    l.location_name

ORDER BY utilization_rate DESC;

SELECT
    p.specialty,

    COUNT(*) AS total_appointments,

    CONVERT(
        DECIMAL(5,2),
        AVG(
            DATEDIFF(
                DAY,
                a.scheduled_date,
                a.appointment_date
            )
        )
    ) AS avg_wait_days,

    MIN(
        DATEDIFF(
            DAY,
            a.scheduled_date,
            a.appointment_date
        )
    ) AS min_wait_days,

    MAX(
        DATEDIFF(
            DAY,
            a.scheduled_date,
            a.appointment_date
        )
    ) AS max_wait_days

FROM appointments a

JOIN providers p
    ON a.provider_id = p.provider_id

WHERE a.status = 'Completed'

GROUP BY p.specialty

ORDER BY avg_wait_days DESC;

SELECT
    pt.insurance_type,

    COUNT(*) AS total_appointments,

    SUM(
        CASE
            WHEN a.status = 'No-Show'
            THEN 1
            ELSE 0
        END
    ) AS no_show_count,

    CONVERT(
        DECIMAL(5,2),
        (
            SUM(
                CASE
                    WHEN a.status = 'No-Show'
                    THEN 1
                    ELSE 0
                END
            ) * 100.0
        ) / COUNT(*)
    ) AS no_show_rate

FROM appointments a

JOIN patients pt
    ON a.patient_id = pt.patient_id

GROUP BY pt.insurance_type

ORDER BY no_show_rate DESC;

SELECT
    p.specialty,

    COUNT(*) AS total_appointments,

    SUM(
        CASE
            WHEN a.status = 'No-Show'
            THEN 1
            ELSE 0
        END
    ) AS no_show_count,

    CONVERT(
        DECIMAL(5,2),
        (
            SUM(
                CASE
                    WHEN a.status = 'No-Show'
                    THEN 1
                    ELSE 0
                END
            ) * 100.0
        ) / COUNT(*)
    ) AS no_show_rate

FROM appointments a

JOIN providers p
    ON a.provider_id = p.provider_id

GROUP BY p.specialty

ORDER BY no_show_rate DESC;

WITH provider_utilization AS (

    SELECT
        p.specialty,

        CONVERT(
            DECIMAL(5,2),
            ROUND(
                (
                    SUM(COALESCE(a.duration_minutes, 0))
                    * 100.0
                ) /
                NULLIF(
                    SUM(pa.available_minutes),
                    0
                ),
                2
            )
        ) AS utilization_rate,

        SUM(pa.available_minutes)
            - SUM(COALESCE(a.duration_minutes, 0))
            AS unused_provider_minutes

    FROM provider_availability pa

    JOIN providers p
        ON pa.provider_id = p.provider_id

    LEFT JOIN appointments a
        ON pa.provider_id = a.provider_id
        AND pa.availability_date = a.appointment_date
        AND a.status = 'Completed'

    GROUP BY p.specialty
),

wait_times AS (

    SELECT
        p.specialty,

        CONVERT(
            DECIMAL(5,2),
            AVG(
                DATEDIFF(
                    DAY,
                    a.scheduled_date,
                    a.appointment_date
                )
            )
        ) AS avg_wait_days

    FROM appointments a

    JOIN providers p
        ON a.provider_id = p.provider_id

    WHERE a.status = 'Completed'

    GROUP BY p.specialty
),

no_show_rates AS (

    SELECT
        p.specialty,

        CONVERT(
            DECIMAL(5,2),
            (
                SUM(
                    CASE
                        WHEN a.status = 'No-Show'
                        THEN 1
                        ELSE 0
                    END
                ) * 100.0
            ) / COUNT(*)
        ) AS no_show_rate

    FROM appointments a

    JOIN providers p
        ON a.provider_id = p.provider_id

    GROUP BY p.specialty
),

referral_pressure AS (

    SELECT
        specialty,

        COUNT(*) AS total_referrals,

        CONVERT(
            DECIMAL(5,2),
            AVG(
                DATEDIFF(
                    DAY,
                    referral_date,
                    appointment_needed_by
                )
            )
        ) AS avg_referral_window_days

    FROM referrals

    GROUP BY specialty
)

SELECT
    pu.specialty,

    pu.utilization_rate,

    wt.avg_wait_days,

    ns.no_show_rate,

    rp.total_referrals,

    rp.avg_referral_window_days,

    pu.unused_provider_minutes,

    CASE
        WHEN
            wt.avg_wait_days >= 35
            AND pu.utilization_rate >= 15
        THEN 'High Bottleneck Risk'

        WHEN
            wt.avg_wait_days >= 20
            OR pu.utilization_rate >= 10
        THEN 'Moderate Bottleneck Risk'

        ELSE 'Stable / Opportunity Area'
    END AS bottleneck_severity

FROM provider_utilization pu

JOIN wait_times wt
    ON pu.specialty = wt.specialty

JOIN no_show_rates ns
    ON pu.specialty = ns.specialty

JOIN referral_pressure rp
    ON pu.specialty = rp.specialty

ORDER BY
    wt.avg_wait_days DESC,
    pu.utilization_rate DESC;
