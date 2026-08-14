using System.Diagnostics;
using Atlaslabs.Models;
using Atlaslabs.Services;
using Microsoft.AspNetCore.Mvc;

namespace Atlaslabs.Controllers
{
    public class HomeController : Controller
    {
        private readonly IChatService _chatService;
        private readonly ILogger<HomeController> _logger;

        public HomeController(IChatService chatService, ILogger<HomeController> logger)
        {
            _chatService = chatService;
            _logger = logger;
        }

        public IActionResult Index()
        {
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Chat([FromBody] string message)
        {
            try
            {
                var response = await _chatService.SendMessageAsync(message);
                return Json(new { response });
            }
            catch (Exception ex)
            {
                // Log the error for debugging
                //
                Console.WriteLine($"Chat error: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");

                // Return detailed error in development/for debugging
                return StatusCode(500, new
                {
                    error = ex.Message,
                    details = ex.InnerException?.Message,
                    type = ex.GetType().Name
                });
            }
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }

    public class ChatRequest
    {
        public string Message { get; set; } = string.Empty;
    }
}
