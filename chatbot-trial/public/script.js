const chatMessages = document.getElementById('chatMessages');
const userInput = document.getElementById('userInput');
const sendButton = document.getElementById('sendButton');
const modelSelect = document.getElementById('modelSelect');
const typingIndicator = document.getElementById('typingIndicator');

let isGenerating = false;
let conversationHistory = [];

// Fungsi untuk memformat pesan agar code snippet markdown (```)
// diubah menjadi elemen <pre><code>
function formatMessage(text) {
  return text.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
    return `<pre><code class="language-${lang || ''}">${code}</code></pre>`;
  });
}

async function sendMessage() {
  if (isGenerating || !userInput.value.trim()) return;
  
  const userMessage = { role: "user", content: userInput.value.trim() };
  conversationHistory.push(userMessage);
  addMessage(userMessage.content, true);
  userInput.value = '';
  
  isGenerating = true;
  typingIndicator.style.display = 'flex';
  window.scrollTo(0, document.body.scrollHeight);
  
  try {
    // Kirim seluruh riwayat percakapan untuk konteks
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        messages: conversationHistory,
        model: modelSelect.value,
        max_tokens: 500
      })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(data.error);
    
    const botMessage = { role: "assistant", content: data.response };
    conversationHistory.push(botMessage);
    addMessage(botMessage.content, false);
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
  
  // Gunakan innerHTML untuk merender HTML code snippet
  messageDiv.innerHTML = formatMessage(text);
  
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
