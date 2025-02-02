import express from 'express';
import { OpenAI } from 'openai';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

// Definisikan __dirname untuk ES Modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 3000;

// Inisialisasi klien OpenAI dengan baseURL OpenRouter
const openai = new OpenAI({
  baseURL: "https://openrouter.ai/api/v1",
  apiKey: process.env.OPENROUTER_API_KEY
});

// Mapping model dari front-end ke model OpenRouter
const modelMapping = {
  "GPT-3.5 Turbo": "openai/gpt-3.5-turbo",
  "Qwen Turbo": "qwen/qwen-turbo",
  "DeepSeek R1 Free": "deepseek/deepseek-r1:free",
  "Liquid LFM-7B": "liquid/lfm-7b"
};

const defaultModelKey = "GPT-3.5 Turbo";

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.post('/api/chat', async (req, res) => {
  const { messages, model } = req.body;
  const selectedModelKey = model in modelMapping ? model : defaultModelKey;
  const chosenModel = modelMapping[selectedModelKey];
  
  try {
    const completion = await openai.chat.completions.create({
      model: chosenModel,
      messages: messages,
      max_tokens: 500
    });
    
    // Kirim properti "content" dari pesan respons
    res.json({ response: completion.choices[0].message.content });
  } catch (error) {
    console.error("Error calling OpenRouter API:", error);
    res.status(500).json({ error: "Error calling OpenRouter API. Pastikan API key dan model valid." });
  }
});

app.listen(port, () => {
  console.log(`Server berjalan pada http://localhost:${port}`);
});
