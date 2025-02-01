import express from 'express';
import { HfInference } from '@huggingface/inference';
import path from 'path';
import bodyParser from 'body-parser';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 3000;
const hfApiKey = process.env.HUGGINGFACE_API_KEY;
const hfClient = new HfInference(hfApiKey);

const models = {
  'DeepSeek-R1': 'deepseek-ai/DeepSeek-R1',
  'DeepSeek-V3': 'deepseek-ai/DeepSeek-V3',
  'DeepSeek-R1-Distill-Qwen-32B': 'deepseek-ai/DeepSeek-R1-Distill-Qwen-32B',
  'gpt2' : 'openai-community/gpt2'
};

app.use(express.static(path.join(__dirname, 'public')));
app.use(bodyParser.json());

app.post('/api/chat', async (req, res) => {
  const { inputText, model } = req.body;
  const selectedModel = models[model] || models['DeepSeek-R1'];

  try {
    const chatCompletion = await hfClient.chatCompletion({
      model: selectedModel,
      messages: [
        { role: "user", content: inputText }
      ],
      provider: "hf-inference",
      max_tokens: 500
    });
    
    res.json({ response: chatCompletion.choices[0].message });
  } catch (error) {
    console.error('Error calling Hugging Face API:', error);
    res.status(500).json({ response: 'Terjadi kesalahan. Pastikan API key dan model valid.' });
  }
});

app.listen(port, () => {
  console.log(`Server berjalan pada http://localhost:${port}`);
});
