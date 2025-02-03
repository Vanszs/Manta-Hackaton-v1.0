const chatMessages = document.getElementById('chatMessages');
const userInput = document.getElementById('userInput');
const sendButton = document.getElementById('sendButton');
const modelSelect = document.getElementById('modelSelect');
const typingIndicator = document.getElementById('typingIndicator');

let isGenerating = false;
let conversationHistory = [];

function formatMessage(text) {
  return text.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
    return `<pre><code class="language-${lang || ''}">${code}</code></pre>`;
  });
}

async function sendMessage() {
  if (isGenerating || !userInput.value.trim()) return;
  
  const userMessage = { role: "user", content: [{ type: "text", text: userInput.value.trim() }] };
  conversationHistory.push(userMessage);
  addMessage(userMessage.content[0].text, true);
  userInput.value = '';
  
  isGenerating = true;
  typingIndicator.style.display = 'flex';
  window.scrollTo(0, document.body.scrollHeight);
  
  try {

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
    
    const botMessage = { role: "assistant", content: [{ type: "text", text: data.content }] };
    conversationHistory.push(botMessage);
    addMessage(botMessage.content[0].text, false);
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

  messageDiv.innerHTML = formatMessage(text);
  
  chatMessages.appendChild(messageDiv);
  messageDiv.scrollIntoView({ behavior: 'smooth' });
}
sendButton.addEventListener('click', sendMessage);
userInput.addEventListener('keypress', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});

userInput.addEventListener('input', () => {
  userInput.style.height = 'auto';
  userInput.style.height = `${userInput.scrollHeight}px`;
});

document.addEventListener('DOMContentLoaded', () => {
  const debugTierSelect = document.createElement('select');
  debugTierSelect.id = 'debugTierSelect';
  debugTierSelect.style.position = 'absolute';
  debugTierSelect.style.top = '10px';
  debugTierSelect.style.right = '10px';
  debugTierSelect.style.zIndex = '1000';

  const tiers = ['Explorer', 'Scholar', 'Innovator', 'Visionary'];
  tiers.forEach(tier => {
    const option = document.createElement('option');
    option.value = tier;
    option.textContent = tier;
    debugTierSelect.appendChild(option);
  });

  debugTierSelect.addEventListener('change', async () => {
    const selectedTier = debugTierSelect.value;
    try {
      const response = await fetch('/debug/set-tier', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: 'testUser', tier: selectedTier })
      });
      const data = await response.json();
      alert(data.status);
    } catch (error) {
      alert(`Error: ${error.message}`);
    }
  });

  document.body.appendChild(debugTierSelect);
});
