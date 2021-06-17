using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using F1Manager.Functions.Entities;
using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace F1Manager.Functions.Functions.Users
{
    public static class RefreshTokensCleanUpFunction
    {

        private const string TableName = "RefreshTokens";
        private const string PartitionKey = "tokens";

        [FunctionName("RefreshTokensCleanUpFunction")]
        public static async Task Run([TimerTrigger("0 0 */5 * * *", RunOnStartup = true)]TimerInfo timer,
            [Table(TableName)] CloudTable table,
            ILogger log)
        {
            log.LogInformation("Executing clean-up task for refresh tokens");
            var partitionKeyFilter = TableQuery.GenerateFilterCondition(nameof(RefreshTokenEntity.PartitionKey),
                QueryComparisons.Equal, PartitionKey);
            var revokedFilter = TableQuery.GenerateFilterConditionForBool(nameof(RefreshTokenEntity.IsRevoked),
                QueryComparisons.Equal, true);
            var activeFilter = TableQuery.GenerateFilterConditionForBool(nameof(RefreshTokenEntity.IsActive),
                QueryComparisons.Equal, false);
            var dateFilter = TableQuery.GenerateFilterConditionForDate(nameof(RefreshTokenEntity.ExpiresOn),
                QueryComparisons.LessThanOrEqual, DateTimeOffset.UtcNow);

            var rovekedAndActive = TableQuery.CombineFilters(revokedFilter, TableOperators.Or, activeFilter);
            var allFilters = TableQuery.CombineFilters(dateFilter, TableOperators.Or, rovekedAndActive);
            var finalFilter = TableQuery.CombineFilters(partitionKeyFilter, TableOperators.And, allFilters);

            var query = new TableQuery<RefreshTokenEntity>().Where(finalFilter);


            var oldRefreshTokens = new List<RefreshTokenEntity>();
            TableContinuationToken ct = null;
            do
            {
                var segment = await table.ExecuteQuerySegmentedAsync(query, ct);
                oldRefreshTokens.AddRange(segment.Results);
            } while (ct != null);

            log.LogInformation("Fetched {count} refresh tokens to clean up", oldRefreshTokens.Count);

            var batch = new TableBatchOperation();
            foreach (var refreshTokenEntity in oldRefreshTokens)
            {
                batch.Add(TableOperation.Delete(refreshTokenEntity));
                if (batch.Count >= 90)
                {
                    await table.ExecuteBatchAsync(batch);
                }
            }

            if (batch.Count > 0)
            {
                await table.ExecuteBatchAsync(batch);
            }

            log.LogInformation("Refresh token clean up procedure succeeded");
            log.LogInformation($"Refresh timer next run scheduled on {timer.Schedule.GetNextOccurrence(DateTime.Now)}");

        }
    }
}
