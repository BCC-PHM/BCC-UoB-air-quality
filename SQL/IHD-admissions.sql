-- IHD (I21-I22, 30+ years old)

WITH FirstIHDAdmission AS (
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
        -- IHD Diagnosis code I21-I22 
        A.[DiagnosisCode] LIKE 'I2[1-2]%'
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
FROM FirstIHDAdmission
WHERE rn = 1
GROUP BY
    LowerLayerSuperOutputArea;
