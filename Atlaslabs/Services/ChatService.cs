using Azure.AI.Extensions.OpenAI;
using Azure.AI.Projects;
using Azure.Identity;

namespace Atlaslabs.Services
{
    public class ChatService : IChatService
    {
        private readonly ILogger<ChatService> _logger;
        private readonly IConfiguration _configuration;
        private readonly List<string> _chatHistory;

        private readonly string _projectEndpoint;
        private readonly string _agentName;

        private readonly AIProjectClient? projectClient;
        private string outputText = string.Empty;

        public ChatService(IConfiguration configuration, ILogger<ChatService> logger)
        {
            _logger = logger;
            _configuration = configuration;
            _chatHistory = [];

            // Read configuration from appsettings.json
            _projectEndpoint = _configuration["AzureAI:ProjectEndpoint"]
                ?? throw new InvalidOperationException("AzureAI:ProjectEndpoint configuration is missing");
            _agentName = _configuration["AzureAI:AgentName"]
                ?? throw new InvalidOperationException("AzureAI:AgentName configuration is missing");

            try
            {
                projectClient = new AIProjectClient(new Uri(_projectEndpoint), new DefaultAzureCredential());
                _logger.LogInformation("AIProjectClient initialized with DefaultAzureCredential. Endpoint: {Endpoint}, Agent: {Agent}",
                    _projectEndpoint, _agentName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize AIProjectClient with endpoint: {Endpoint}", _projectEndpoint);
                throw;
            }
        }

        public async Task<string> SendMessageAsync(string userMessage, CancellationToken cancellationToken = default)
        {
            try
            {
                _logger.LogInformation("Sending message: {Message}", userMessage);

                if (projectClient == null)
                {
                    throw new InvalidOperationException("Project client is not initialized");
                }

                // Get the agent record, extract identifier, and create an AgentReference
                var agentResult = projectClient.AgentAdministrationClient.GetAgent(_agentName);
                var agentRecord = agentResult.Value
                                 ?? throw new InvalidOperationException($"Agent '{_agentName}' not found");
                
                var agentRef = new AgentReference(agentRecord.Id ?? agentRecord.Name ?? _agentName);

                var responseClient = projectClient.ProjectOpenAIClient.GetProjectResponsesClientForAgent(agentRef);

                var rr = await responseClient.CreateResponseAsync(userInputText: userMessage, cancellationToken: cancellationToken);

                outputText = rr.Value.GetOutputText() ?? string.Empty;

                _chatHistory.Add($"User: {userMessage}");
                _chatHistory.Add($"Assistant: {outputText}");

                _logger.LogInformation("Response generated successfully");

                return outputText;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in SendMessageAsync for message: {Message}", userMessage);
                throw;
            }
        }

        public Task<IEnumerable<string>> GetChatHistoryAsync()
        {
            return Task.FromResult<IEnumerable<string>>(_chatHistory);
        }

        public Task ClearHistoryAsync()
        {
            _chatHistory.Clear();
            _logger.LogInformation("Chat history cleared");
            return Task.CompletedTask;
        }
    }
}
