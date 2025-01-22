require('dotenv').config();  // Load environment variables from .env
const axios = require('axios');
const readline = require('readline');

// Set up readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// Set your Hugging Face API key from the environment variable
const apiKey = process.env.HUGGINGFACE_API_KEY;

// Available models (user will choose one of these)
const models = {
  '1': 'gpt2',
  '2': 'deepsek-ai/DeepSeek-R1-Distill-Qwen-14B',
  '3': 'deepseek/v3',
  '4': 'microsoft/phi-4',
};

// Function to interact with the Hugging Face API
const getHuggingFaceResponse = async (inputText, model) => {
  const apiEndpoint = `https://api-inference.huggingface.co/models/${model}`;
  
  try {
    // Making the API request
    const response = await axios.post(
      apiEndpoint,
      { inputs: inputText },  // The input text to send to the model
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,  // Using your API key to authenticate the request
        },
      }
    );

    // Return the generated text from the model
    return response.data[0]?.generated_text || 'Sorry, I couldn\'t generate a response.';
  } catch (error) {
    console.error('Error calling Hugging Face API:', error);
    return 'An error occurred while processing your request.';
  }
};

// Function to ask the user for a model selection
const selectModel = () => {
  return new Promise((resolve) => {
    rl.question('Select a model (1: GPT-2, 2: DeepseekR1, 3: DeepSeekV3, 4: Phi-4): ', (choice) => {
      if (models[choice]) {
        console.log(`You selected: ${models[choice]}`);
        resolve(models[choice]); // Return the selected model
      } else {
        console.log('Invalid choice, defaulting to GPT-2');
        resolve(models['1']); // Default to GPT-2 if input is invalid
      }
    });
  });
};

// Function to handle user chat interaction
const chat = async () => {
  const selectedModel = await selectModel(); // Wait for user to select a model

  rl.question('You: ', async (userInput) => {
    if (userInput.toLowerCase() === 'exit') {
      rl.close();
      return;
    }

    const chatbotResponse = await getHuggingFaceResponse(userInput, selectedModel);
    console.log('Chatbot: ', chatbotResponse);

    // Continue the conversation
    chat();
  });
};

// Start the chat loop
chat();
