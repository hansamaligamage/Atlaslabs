# Atlaslabs

Atlaslabs is an ASP.NET Core web application that provides a chat interface powered by an **Azure AI Foundry** agent. Users can send messages through the web UI and receive AI-generated responses from a configured Azure AI agent named **Atlas-buddy**.

---

## Features

- 🤖 Real-time chat with an Azure AI Foundry agent
- 🔐 Secure authentication via Azure Managed Identity (`DefaultAzureCredential`)
- 🌐 ASP.NET Core MVC web application targeting .NET 10
- ☁️ Deployable to Azure App Service via GitHub Actions.

---

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- An **Azure AI Foundry** project with a deployed agent
- Azure CLI (for deployment)
- Azure subscription with appropriate permissions

---

## Configuration

The application reads its settings from `appsettings.json` (or environment variables / Azure App Service settings):

| Key | Description |
|-----|-------------|
| `AzureAI:ProjectEndpoint` | The endpoint URL of your Azure AI Foundry project |
| `AzureAI:AgentName` | The name of the AI agent to use (e.g., `Atlas-buddy`) |

Example `appsettings.json`:

```json
{
  "AzureAI": {
    "ProjectEndpoint": "https://<your-resource>.services.ai.azure.com/api/projects/<your-project>",
    "AgentName": "Atlas-buddy"
  }
}
```

> **Note:** The application uses `DefaultAzureCredential` for authentication. When running locally, make sure you are logged in with `az login` or have the appropriate environment variables set.

---

## Getting Started

### Run Locally

```bash
# Clone the repository
git clone https://github.com/hansamaligamage/Atlaslabs.git
cd Atlaslabs

# Restore dependencies
dotnet restore

# Run the application
dotnet run --project Atlaslabs
```

The application will be available at `https://localhost:5001` (or the port shown in the terminal).

---

## Project Structure

```
Atlaslabs/
├── Controllers/
│   └── HomeController.cs       # Handles web requests and chat API endpoint
├── Models/
│   └── ErrorViewModel.cs       # Error view model
├── Services/
│   ├── IChatService.cs         # Chat service interface
│   └── ChatService.cs          # Azure AI Foundry chat implementation
├── Views/                      # Razor views (UI)
├── wwwroot/                    # Static assets (CSS, JS)
├── appsettings.json            # Application configuration
└── Program.cs                  # Application entry point
```

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | ASP.NET Core MVC (.NET 10) |
| AI Integration | Azure AI Projects SDK (`Azure.AI.Projects`) |
| Authentication | Azure Identity (`DefaultAzureCredential`) |
| Hosting | Azure App Service |
| CI/CD | GitHub Actions  |

---

## License

This project is provided as-is for demonstration and learning purposes.
