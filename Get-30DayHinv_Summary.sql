SELECT TOP 30
    month(lasthw) [Month], day(lasthw) [Day], year(lasthw) [Year], count(*) [Count]
FROM v_r_system_valid sys JOIN
    v_ch_clientsummary cs ON sys.resourceid = cs.resourceid
GROUP BY month(lasthw), day(lasthw), year(lasthw)
ORDER BY year(lasthw) DESC, month(lasthw) DESC, day(lasthw) DESC
