namespace Atlaslabs.Services
{
    public interface IChatService
    {
        Task<string> SendMessageAsync(string userMessage, CancellationToken cancellationToken = default);
        Task<IEnumerable<string>> GetChatHistoryAsync();
        Task ClearHistoryAsync();
    }
}
