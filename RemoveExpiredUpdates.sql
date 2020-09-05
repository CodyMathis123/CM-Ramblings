-- Delete expired updates that have beem marked as expired for more than @Days 
DECLARE @Days as int = 0
exec spDeleteExpiredUpdates @Days
