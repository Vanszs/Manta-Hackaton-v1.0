import 'dotenv/config';
import OpenAI from "openai";
import express from 'express';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';
import rateLimit from 'express-rate-limit';
import { createProxyMiddleware } from 'http-proxy-middleware';
import cors from 'cors';
const openai = new OpenAI({
  baseURL: "https://openrouter.ai/api/v1",
  apiKey: process.env.OPENROUTER_API_KEY,
  defaultHeaders: {
    "HTTP-Referer": "www.google.com",
    "X-Title": "ArcalisAI"
  }
});

const redis = new Redis(process.env.REDIS_URL);
const app = express();
app.use(express.json());
app.use(cors()); 

import path from 'path';
import { fileURLToPath } from 'url';

// Konversi __dirname untuk ES module
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Mengatur folder statis
app.use(express.static(path.join(__dirname, 'public')));

// Route untuk menyajikan index.html
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});


// Model Configuration
const MODEL_CONFIG = {
  'deepseek/deepseek-r1:free': {
    reasoning: true,
    multimodal: false,
    maxTokens: 2000,
    pricePerToken: 0.000002,
    imageSupport: false
  },
  'minimax/minimax-01': {
    reasoning: false,
    multimodal: true,
    maxTokens: 4000,
    pricePerToken: 0.000005,
    imageSupport: true,
    imageFormats: ['url', 'base64'],
    maxImageSize: 5,
    maxImages: 3
  },
  'qwen/qwen-turbo': {
    reasoning: true,
    multimodal: false,
    maxTokens: 6000,
    pricePerToken: 0.000003,
    imageSupport: false
  },
  'liquid/lfm-7b': {
    reasoning: false,
    multimodal: false,
    maxTokens: 8000,
    pricePerToken: 0.000004,
    imageSupport: false
  },
  'google/gemini-2.0-flash-thinking-exp:free': {
    reasoning: true,
    multimodal: true,
    maxTokens: 12000,
    pricePerToken: 0.000007,
    imageSupport: true,
    imageFormats: ['url'],
    maxImageSize: 10,
    maxImages: 5
  },
  'microsoft/phi-4': {
    reasoning: true,
    multimodal: true,
    maxTokens: 32000,
    pricePerToken: 0.00001,
    imageSupport: true,
    imageFormats: ['base64'],
    maxImageSize: 15,
    specialParams: {
      detail: "high"
    }
  }
};

// Tier Configuration
const TIER_CONFIG = {
  'Explorer': {
    modelAccess: {
      'deepseek/deepseek-r1:free': { dailyLimit: Infinity },
      'minimax/minimax-01': { dailyLimit: 20 }
    },
    features: {
      reasoning: true,
      search: false,
      memory: {
        enabled: true,
        maxSessions: 3,
        retentionDays: 7,
        maxMessages: 100
      },
      contextLength: 4,
      imageUpload: true,
      maxImageUploads: 20
    },
    priority: 1
  },
  'Scholar': {
    modelAccess: {
      'deepseek/deepseek-r1:free': Infinity,
      'qwen/qwen-turbo': 100,
      'minimax/minimax-01': 100
    },
    features: {
      reasoning: true,
      search: true,
      memory: {
        enabled: true,
        maxSessions: 10,
        retentionDays: 30,
        maxMessages: 500
      },
      contextLength: 8,
      imageUpload: true,
      maxImageUploads: 100
    },
    priority: 2
  },
  'Innovator': {
    modelAccess: {
      'deepseek/deepseek-r1:free': Infinity,
      'qwen/qwen-turbo': 500,
      'liquid/lfm-7b': 500,
      'minimax/minimax-01': 500,
      'google/gemini-2.0-flash-thinking-exp:free': 500
    },
    features: {
      reasoning: true,
      search: true,
      memory: {
        enabled: true,
        maxSessions: 50,
        retentionDays: 90,
        maxMessages: 5000
      },
      contextLength: 16,
      imageUpload: true,
      maxImageUploads: 500
    },
    priority: 3
  },
  'Visionary': {
    modelAccess: {
      'deepseek/deepseek-r1:free': Infinity,
      'minimax/minimax-01': Infinity,
      'qwen/qwen-turbo': Infinity,
      'liquid/lfm-7b': Infinity,
      'google/gemini-2.0-flash-thinking-exp:free': Infinity,
      'microsoft/phi-4': Infinity
    },
    features: {
      reasoning: true,
      search: true,
      memory: {
        enabled: true,
        maxSessions: Infinity,
        retentionDays: Infinity,
        maxMessages: Infinity
      },
      contextLength: Infinity,
      imageUpload: true,
      maxImageUploads: Infinity
    },
    priority: 4
  }
};

// Middleware Utama
const sanitizeInput = (req, res, next) => {
  req.body.messages = req.body.messages.map(msg => ({
    ...msg,
    content: msg.content.filter(content => {
      if (content.type === 'text') {
        return !/[<>{}]/.test(content.text);
      }
      if (content.type === 'image_url') {
        return /^(https?|data:image)/i.test(content.image_url.url);
      }
      return true;
    })
  }));
  next();
};

const imageRateLimiter = rateLimit({
  windowMs: 24 * 60 * 60 * 1000,
  keyGenerator: req => `img_limit:${req.userId}`,
  handler: (req, res) => res.status(429).json({ 
    error: "Batas harian gambar tercapai",
    limit: TIER_CONFIG[req.tier].features.maxImageUploads
  }),
  skip: req => req.tier === 'Visionary',
  max: req => TIER_CONFIG[req.tier].features.maxImageUploads
});

// Context Management
const crossModelMemory = async (req, res, next) => {
  const { model, messages } = req.body;
  const tier = TIER_CONFIG[req.tier];
  
  try {
    const rawHistory = await redis.lrange(`session:${req.sessionId}`, 0, -1);
    const processedHistory = rawHistory
      .map(JSON.parse)
      .filter(msg => isCompatibleWithModel(msg, model))
      .slice(-tier.features.contextLength);

    const processedMessages = processMessages(messages, model);
    const finalMessages = [...processedHistory, ...processedMessages]
      .slice(-tier.features.contextLength);

    await redis.lpush(`session:${req.sessionId}`, ...finalMessages);
    req.processedMessages = finalMessages;
    next();
  } catch (error) {
    next(error);
  }
};

const isCompatibleWithModel = (message, model) => {
  const modelConfig = MODEL_CONFIG[model];
  return message.content.every(content => {
    if (content.type === 'image_url') {
      const isBase64 = content.image_url.url.startsWith('data:image');
      return modelConfig.imageSupport && 
        modelConfig.imageFormats.includes(isBase64 ? 'base64' : 'url') &&
        content.image_url.url.length <= modelConfig.maxImageSize * 1024 * 1024;
    }
    return true;
  });
};

const processMessages = (messages, model) => {
  return messages.map(msg => ({
    ...msg,
    content: msg.content.map(content => {
      if (content.type === 'image_url') {
        return processImageContent(content, model);
      }
      return content;
    })
  }));
};

const processImageContent = (content, model) => {
  const modelConfig = MODEL_CONFIG[model];
  const isBase64 = content.image_url.url.startsWith('data:image');
  
  if (isBase64) {
    const sizeMB = (content.image_url.url.length * 3/4) / (1024*1024);
    if (sizeMB > modelConfig.maxImageSize) {
      throw new Error(`Ukuran gambar melebihi batas ${modelConfig.maxImageSize}MB`);
    }
  }
  
  return {
    ...content,
    image_url: {
      url: isBase64 ? 
        content.image_url.url.split(',')[1] : 
        content.image_url.url,
      format: isBase64 ? 'base64' : 'url'
    }
  };
};

// Error Handling
const handleApiError = (err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message,
    ...(process.env.DEBUG && { stack: err.stack })
  });
};

// API Endpoints
app.post('/api/chat', 
  authenticate,
  sanitizeInput,
  imageRateLimiter,
  crossModelMemory,
  async (req, res, next) => {
    try {
      const { model } = req.body;
      const response = await openai.chat.completions.create({
        model,
        messages: req.processedMessages,
        max_tokens: MODEL_CONFIG[model].maxTokens,
        temperature: 0.7
      });

      const result = {
        content: response.choices[0].message.content,
        sessionId: req.sessionId
      };

      if (MODEL_CONFIG[model].reasoning) {
        result.reasoning = extractReasoning(response);
        await redis.hset(`reasoning:${req.sessionId}`, Date.now(), result.reasoning);
      }

      res.json(result);
    } catch (error) {
      next(error);
    }
  }
);

app.get('/api/reasoning/:sessionId', async (req, res) => {
  const reasoning = await redis.hgetall(`reasoning:${req.params.sessionId}`);
  res.json({ 
    reasoning: Object.values(reasoning),
    count: Object.keys(reasoning).length
  });
});

// Debug Endpoints
app.post('/debug/reset', (req, res) => {
  if (process.env.NODE_ENV === 'development') {
    redis.flushall();
    res.json({ status: 'Semua data direset' });
  }
});

app.post('/debug/set-limit', (req, res) => {
  if (process.env.NODE_ENV === 'development') {
    const { key, value } = req.body;
    redis.set(`limit:${key}`, value);
    res.json({ status: 'Limit diperbarui' });
  }
});

app.post('/debug/set-tier', (req, res) => {
  if (process.env.NODE_ENV === 'development') {
    const { userId, tier } = req.body;
    redis.set(`tier:${userId}`, tier);
    res.json({ status: `Tingkat akses ${userId} diubah menjadi ${tier}` });
  }
});

// Helper Functions
function extractReasoning(response) {
  try {
    const content = response.choices[0].message.content;
    const reasoningStart = content.indexOf('Reasoning:');
    return reasoningStart > -1 ? 
      content.slice(reasoningStart + 10) : 
      'Tidak ada reasoning tersedia';
  } catch {
    return 'Gagal mengekstrak reasoning';
  }
}

// Middleware untuk otentikasi (contoh sederhana)
function authenticate(req, res, next) {
  req.userId = 'testUser'; // ID pengguna statis untuk tujuan debugging
  req.tier = 'Explorer'; // Tingkat akses default
  req.sessionId = uuidv4(); // ID sesi unik
  next();
}




// Error Handling Middleware
app.use(handleApiError);

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server berjalan di port ${PORT}`);
});
