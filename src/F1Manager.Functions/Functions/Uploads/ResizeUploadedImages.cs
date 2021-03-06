using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Blob;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Extensions.Logging;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Processing;

namespace F1Manager.Functions.Functions.Uploads
{
    public static class ResizeUploadedImages
    {
        [FunctionName("ResizeUploadedImages")]
        public static async Task Run([BlobTrigger("uploads/{name}", Connection = "ComponentImagesStorageAccount")] CloudBlockBlob blob, string name, ILogger log)
        {

            var storageAccountConnectionString = Environment.GetEnvironmentVariable("ComponentImagesStorageAccount");

            await using var input = new MemoryStream();
            await using var output = new MemoryStream();

            await blob.DownloadToStreamAsync(input);
            input.Seek(0, SeekOrigin.Begin);

            var resizeOptions = new ResizeOptions
            {
                Mode = ResizeMode.Crop,
                Position = AnchorPositionMode.Center,
                Size = new Size(512, 512)
            };

            var image = await Image.LoadAsync(input);
            image.Mutate(x => x.Resize(resizeOptions));

            await image.SaveAsync(output, new JpegEncoder());
            output.Seek(0, SeekOrigin.Begin);


            if (CloudStorageAccount.TryParse(storageAccountConnectionString, out var storageAccount))
            {
                var cloudBlobClient = storageAccount.CreateCloudBlobClient();
                var cloudBlobContainer = cloudBlobClient.GetContainerReference("images");
                await cloudBlobContainer.CreateIfNotExistsAsync();

                var permissions = new BlobContainerPermissions
                {
                    PublicAccess = BlobContainerPublicAccessType.Blob
                };

                await cloudBlobContainer.SetPermissionsAsync(permissions);

                var cloudBlockBlob = cloudBlobContainer.GetBlockBlobReference($"{name}.jpg");
                cloudBlockBlob.Properties.ContentType = "image/jpg";
                await cloudBlockBlob.UploadFromStreamAsync(output);
            }

            await blob.DeleteIfExistsAsync();
        }
    }
}
