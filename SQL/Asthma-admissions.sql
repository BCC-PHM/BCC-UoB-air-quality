-- Asthma in Children (J45, 0-18 years old) and adults (J45, 19+ years old)

WITH FirstAsthmaAdmission AS (
    SELECT
        A.EpisodeId,
        B.NHSNumber,
        B.LowerLayerSuperOutputArea,
        B.AdmissionDate,
        B.AgeOnAdmission,
        ROW_NUMBER() OVER (
            PARTITION BY B.NHSNumber
            ORDER BY B.AdmissionDate ASC, A.EpisodeId
        ) AS rn
    FROM 
        [EAT_Reporting_BSOL].[SUS].[VwInpatientEpisodesDiagnosisRelational] AS A
    LEFT JOIN 
        [EAT_Reporting_BSOL].[SUS].[VwInpatientEpisodesPatientGeography] AS B
        ON A.[EpisodeId] = B.[EpisodeId]
    WHERE 
        -- Asthma Diagnosis code J45 
        A.[DiagnosisCode] LIKE 'J45%'
        -- First reason for admission
        AND A.[DiagnosisOrder] = 1
        -- 2025
        AND B.[AdmissionDate] >= '2025-01-01'
        AND B.[AdmissionDate] < '2026-01-01'
)

SELECT
    LowerLayerSuperOutputArea AS LSOA_CODE,
    SUM(CASE WHEN AgeOnAdmission <= 18 THEN 1 ELSE 0 END) AS Children_Admissions,
    SUM(CASE WHEN AgeOnAdmission >= 19 THEN 1 ELSE 0 END) AS Adult_Admissions
FROM FirstAsthmaAdmission
WHERE rn = 1
GROUP BY
    LowerLayerSuperOutputArea;
