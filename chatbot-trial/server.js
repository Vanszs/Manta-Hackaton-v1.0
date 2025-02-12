import 'dotenv/config';
import OpenAI from "openai";
import express from 'express';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';
import cors from 'cors';
import { createParser } from 'eventsource-parser';

const redis = new Redis(process.env.REDIS_URL);
const openai = new OpenAI({
  baseURL: "https://openrouter.ai/api/v1",
  apiKey: process.env.OPENROUTER_API_KEY,
  defaultHeaders: {
    "HTTP-Referer": "www.google.com",
    "X-Title": "ArcalisAI"
  }
});

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

const app = express();
app.use(express.json());
app.use(cors());

// Model Configuration (OpenRouter Docs Compliant)
// Model Configuration
const MODEL_CONFIG = {
  'deepseek/deepseek-r1:free': {
    reasoning: true,
    multimodal: false,
    maxTokens: 32768,
    pricePerToken: 0.000002,
    features: ['text-processing'],
    supportsSchema: true
  },
  'minimax/minimax-01': {
    reasoning: false,
    multimodal: true,
    maxTokens: 131072,
    pricePerToken: 0.000005,
    features: ['image-analysis', 'web-search'],
    imageSpecs: {
      formats: ['url', 'base64'],
      maxSizeMB: 10
    }
  },
  'qwen/qwen-turbo': {
    reasoning: true,
    multimodal: false,
    maxTokens: 65536,
    pricePerToken: 0.0000035,
    features: ['fast-inference', 'long-context']
  },
  'liquid/lfm-7b': {
    reasoning: false,
    multimodal: false,
    maxTokens: 32768,
    pricePerToken: 0.0000028,
    features: ['low-latency']
  },
  'google/gemini-2.0-flash-thinking-exp': {
    reasoning: true,
    multimodal: true,
    maxTokens: 262144,
    pricePerToken: 0.000007,
    features: ['multi-modal', 'web-search']
  },
  'microsoft/phi-4': {
    reasoning: true,
    multimodal: true,
    maxTokens: 131072,
    pricePerToken: 0.0000085,
    features: ['data-analysis', 'code-interpretation']
  }
};

// Tier Configuration
const TIER_CONFIG = {
  'Explorer': {
    modelAccess: {
      'deepseek/deepseek-r1:free': Infinity,
      'minimax/minimax-01': 20,
      'qwen/qwen-turbo': 10
    },
    features: {
      webSearch: false,
      cacheTTL: 300,
      maxSessions: Infinity
    }
  },
  
  'Scholar': {
    modelAccess: {
      'deepseek/deepseek-r1:free': Infinity,
      'minimax/minimax-01': 100,
      'qwen/qwen-turbo': 100,
      'liquid/lfm-7b': 20,
      'google/gemini-2.0-flash-thinking-exp': 20
    },
    features: {
      webSearch: true,
      cacheTTL: 1800,
      maxSessions: Infinity
    }
  },
  'Innovator': {
    modelAccess: {
      'deepseek/deepseek-r1:free': Infinity,
      'minimax/minimax-01': 500,
      'qwen/qwen-turbo': 500,
      'liquid/lfm-7b': 500,
      'google/gemini-2.0-flash-thinking-exp': 500,
      'microsoft/phi-4': 30
    },
    features: {
      webSearch: true,
      cacheTTL: 3600,
      maxSessions: Infinity
    }
  },
  'Visionary': {
    modelAccess: {
      'deepseek/deepseek-r1:free': Infinity,
      'minimax/minimax-01': Infinity,
      'qwen/qwen-turbo': Infinity,
      'liquid/lfm-7b': Infinity,
      'google/gemini-2.0-flash-thinking-exp': Infinity,
      'microsoft/phi-4': Infinity
    },

    features: {
      webSearch: true,
      cacheTTL: 86400,
      maxSessions: Infinity
    }
  }
};


// Redis Utilities
const redisClient = {
  cachePrompt: async (key, data, ttl) => {
    await redis.setex(`cache:${key}`, ttl, JSON.stringify(data));
  },

  getCached: async (key) => {
    const data = await redis.get(`cache:${key}`);
    return data ? JSON.parse(data) : null;
  },

  storeMessage: async (sessionId, message) => {
    await redis.rpush(`history:${sessionId}`, JSON.stringify(message));
    await redis.expire(`history:${sessionId}`, 604800); // 7 days
  },

  getHistory: async (sessionId) => {
    const data = await redis.lrange(`history:${sessionId}`, 0, -1);
    return data.map(JSON.parse);
  }
};

// Middleware
app.post('/api/chat', 
  authenticate,
  validateRequest,
  checkCache,
  handleStreaming,
  async (req, res) => {
    if (req.hitCache) return;
    
    try {
      const { model, messages, stream, schema } = req.body;
      const config = MODEL_CONFIG[model];
      const tier = TIER_CONFIG[req.tier];

      const payload = {
        model,
        messages: await buildMessages(req),
        stream,
        max_tokens: config.maxTokens,
        temperature: 0.7,
        ...(config.supportsSchema && schema && {
          response_format: { type: 'json_schema', schema }
        }),
        ...(config.features.includes('web-search') && tier.features.webSearch && {
          extra_body: { web_search: true }
        }),
        ...(config.reasoning && { include_reasoning: true })
      };

      if (stream) {
        await handleStreamingResponse(req, res, payload);
      } else {
        const response = await openai.chat.completions.create(payload);
        await handleResponse(req, res, response);
      }
    } catch (error) {
      handleError(error, res);
    }
  }
);

// Helper Functions
async function authenticate(req, res, next) {
  req.userId = 'user123'; // Implement proper auth
  req.tier = 'Explorer'; // Implement tier lookup
  req.sessionId = uuidv4();
  next();
}

async function validateRequest(req, res, next) {
  const { model } = req.body;
  if (!MODEL_CONFIG[model] || !TIER_CONFIG[req.tier].modelAccess[model]) {
    return res.status(403).json({ error: "Model not available for your tier" });
  }
  next();
}

async function checkCache(req, res, next) {
  if (req.body.stream) return next();
  
  const cacheKey = `model:${req.body.model}:prompt:${JSON.stringify(req.body.messages)}`;
  const cached = await redisClient.getCached(cacheKey);
  
  if (cached) {
    req.hitCache = true;
    return res.json(cached);
  }
  
  req.cacheKey = cacheKey;
  next();
}

async function buildMessages(req) {
  const history = await redisClient.getHistory(req.sessionId);
  return [
    ...history.map(msg => ({ role: 'assistant', content: msg.content })),
    ...req.body.messages
  ];
}

async function handleStreamingResponse(req, res, payload) {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  const parser = createParser(event => {
    if (event.type === 'event') {
      if (event.data === '[DONE]') {
        res.end();
        return;
      }
      
      try {
        const data = JSON.parse(event.data);
        if (data.choices[0].delta.content) {
          res.write(`data: ${JSON.stringify(data)}\n\n`);
        }
      } catch (e) {
        // Handle parsing errors
      }
    }
  });

  const reader = response.body.getReader();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    parser.feed(new TextDecoder().decode(value));
  }
}

async function handleResponse(req, res, response) {
  const result = {
    content: response.choices[0].message.content,
    reasoning: response.choices[0].message.reasoning,
    model: response.model,
    usage: response.usage
  };

  await redisClient.cachePrompt(
    req.cacheKey, 
    result, 
    TIER_CONFIG[req.tier].features.cacheTTL
  );

  await redisClient.storeMessage(req.sessionId, {
    model: req.body.model,
    ...result
  });

  res.json(result);
}

function handleError(error, res) {
  console.error(error);
  res.status(500).json({
    error: error.message,
    ...(process.env.DEBUG && { stack: error.stack })
  });
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
