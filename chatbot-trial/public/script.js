const chatMessages = document.getElementById('chatMessages');
const userInput = document.getElementById('userInput');
const sendButton = document.getElementById('sendButton');
const modelSelect = document.getElementById('modelSelect');
const typingIndicator = document.getElementById('typingIndicator');

let isGenerating = false;

async function sendMessage() {
  if (isGenerating || !userInput.value.trim()) return;
  
  const message = userInput.value.trim();
  userInput.value = '';
  addMessage(message, true);
  
  isGenerating = true;
  typingIndicator.style.display = 'flex';
  window.scrollTo(0, document.body.scrollHeight);
  
  try {
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        messages: [
          { role: "user", content: message }
        ],
        // Pastikan nilai model sesuai dengan kunci yang digunakan di server.js
        model: modelSelect.value,
        max_tokens: 500
      })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(data.error);
    
    addMessage(data.response, false);
  } catch (error) {
    addMessage(`Error: ${error.message}`, false);
  } finally {
    isGenerating = false;
    typingIndicator.style.display = 'none';
  }
}

function addMessage(text, isUser) {
  const messageDiv = document.createElement('div');
  messageDiv.className = `message ${isUser ? 'user-message' : 'bot-message'}`;
  
  const textContent = document.createElement('div');
  textContent.textContent = text;
  messageDiv.appendChild(textContent);
  
  chatMessages.appendChild(messageDiv);
  messageDiv.scrollIntoView({ behavior: 'smooth' });
}

// Event listeners
sendButton.addEventListener('click', sendMessage);
userInput.addEventListener('keypress', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});

// Auto-resize input
userInput.addEventListener('input', () => {
  userInput.style.height = 'auto';
  userInput.style.height = `${userInput.scrollHeight}px`;
});
