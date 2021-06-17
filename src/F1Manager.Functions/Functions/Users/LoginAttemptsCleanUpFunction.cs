using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using F1Manager.Functions.Entities;
using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace F1Manager.Functions.Functions.Users
{
    public static class LoginAttemptsCleanUpFunction
    {

        private const string TableName = "Logins";
        private const string PartitionKey = "attempts";

        [FunctionName("LoginAttemptsCleanUpFunction")]
        public static async Task Run([TimerTrigger("0 0 */5 * * *", RunOnStartup = true)]TimerInfo timer,
        [Table(TableName)] CloudTable table,
            ILogger log)
        {
            log.LogInformation("Executing clean-up task for login attempts");
            var partitionKeyFilter = TableQuery.GenerateFilterCondition(nameof(LoginAttemptEntity.PartitionKey),
                QueryComparisons.Equal, PartitionKey);
            var dateFilter = TableQuery.GenerateFilterConditionForDate(nameof(LoginAttemptEntity.ExpiresOn),
                QueryComparisons.LessThanOrEqual, DateTimeOffset.UtcNow);

            var allFilters = TableQuery.CombineFilters(partitionKeyFilter, TableOperators.And, dateFilter);

            var query = new TableQuery<LoginAttemptEntity>().Where(allFilters);


            var expiredLoginAttempts = new List<LoginAttemptEntity>();
            TableContinuationToken ct = null;
            do
            {
                var segment = await table.ExecuteQuerySegmentedAsync(query, ct);
                expiredLoginAttempts.AddRange(segment.Results);
            } while (ct != null);

            log.LogInformation("Fetched {count} login attempts to clean up", expiredLoginAttempts.Count);

            var batch = new TableBatchOperation();
            foreach (var expiredLoginAttempt in expiredLoginAttempts)
            {
                batch.Add(TableOperation.Delete(expiredLoginAttempt));
                if (batch.Count >= 90)
                {
                    await table.ExecuteBatchAsync(batch);
                }
            }

            if (batch.Count > 0)
            {
                await table.ExecuteBatchAsync(batch);
            }

            log.LogInformation("Login attempts clean up procedure succeeded");
            log.LogInformation($"Login attempts timer next run scheduled on {timer.Schedule.GetNextOccurrence(DateTime.Now)}");

        }
    }
}
