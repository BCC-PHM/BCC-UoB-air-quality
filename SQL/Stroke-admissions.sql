-- Stroke (I60-64, 30+ years old)

WITH FirstStrokeAdmission AS (
    SELECT
        A.EpisodeId,
        B.NHSNumber,
        B.LowerLayerSuperOutputArea,
        B.AdmissionDate,
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
        -- Stroke Diagnosis code I60-64
        A.[DiagnosisCode] LIKE 'I6[0-4]%'
        -- First reason for admission
        AND A.[DiagnosisOrder] = 1
        -- 2025
        AND B.[AdmissionDate] >= '2025-01-01'
        AND B.[AdmissionDate] < '2026-01-01'
		AND B.AgeOnAdmission >= 30
)

SELECT
    LowerLayerSuperOutputArea AS LSOA_CODE,
    COUNT(*) AS IHD_Admissions
FROM FirstStrokeAdmission
WHERE rn = 1
GROUP BY
    LowerLayerSuperOutputArea;
