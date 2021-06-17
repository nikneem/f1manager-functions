using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Azure.Cosmos.Table;

namespace F1Manager.Functions.Entities
{
    public class LoginAttemptEntity : TableEntity
    {
        public string RsaPrivateKey { get; set; }
        public DateTimeOffset IssuedOn { get; set; }
        public DateTimeOffset ExpiresOn { get; set; }
    }
}
