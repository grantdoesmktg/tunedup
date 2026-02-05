import { GoogleGenerativeAI, GenerativeModel, GenerationConfig } from '@google/generative-ai';

// ============================================
// Gemini Client Wrapper
// ============================================

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

const PRO_MODEL = process.env.GEMINI_PRO_MODEL || 'gemini-2.5-pro-preview-05-06';
const FLASH_MODEL = process.env.GEMINI_FLASH_MODEL || 'gemini-2.5-flash-preview-05-20';

interface GeminiResponse<T> {
  data: T;
  tokensUsed: number;
  promptTokens?: number;
  outputTokens?: number;
}

// Generation config for structured JSON output
const jsonConfig: GenerationConfig = {
  temperature: 0.7,
  topP: 0.95,
  topK: 40,
  maxOutputTokens: 8192,
  responseMimeType: 'application/json',
};

// Generation config for chat (more creative)
const chatConfig: GenerationConfig = {
  temperature: 0.9,
  topP: 0.95,
  topK: 40,
  maxOutputTokens: 1024,
};

// ============================================
// Model Getters
// ============================================

function getProModel(): GenerativeModel {
  return genAI.getGenerativeModel({
    model: PRO_MODEL,
    generationConfig: jsonConfig,
  });
}

function getFlashModel(): GenerativeModel {
  return genAI.getGenerativeModel({
    model: FLASH_MODEL,
    generationConfig: chatConfig,
  });
}

function getFlashModelForPipeline(): GenerativeModel {
  return genAI.getGenerativeModel({
    model: FLASH_MODEL,
    generationConfig: jsonConfig,
  });
}

// ============================================
// Pipeline Calls (Pro or Flash Model - JSON Output)
// ============================================

export async function callPipelineStep<T>(
  prompt: string,
  systemInstruction?: string,
  useFlash: boolean = false
): Promise<GeminiResponse<T>> {
  const model = useFlash ? getFlashModelForPipeline() : getProModel();

  const chat = model.startChat({
    history: systemInstruction
      ? [
          {
            role: 'user',
            parts: [{ text: systemInstruction }],
          },
          {
            role: 'model',
            parts: [{ text: 'Understood. I will follow these instructions.' }],
          },
        ]
      : [],
  });

  const result = await chat.sendMessage(prompt);
  const response = result.response;
  const text = response.text();

  // Parse JSON response
  let data: T;
  try {
    data = JSON.parse(text) as T;
  } catch {
    // Try to extract JSON from markdown code blocks
    const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      data = JSON.parse(jsonMatch[1].trim()) as T;
    } else {
      throw new Error(`Failed to parse JSON response: ${text.slice(0, 200)}`);
    }
  }

  // Get token usage
  const usageMetadata = response.usageMetadata;
  const promptTokens = usageMetadata?.promptTokenCount;
  const outputTokens = usageMetadata?.candidatesTokenCount;
  const tokensUsed = usageMetadata
    ? (promptTokens || 0) + (outputTokens || 0)
    : estimateTokensForText(prompt + text);

  return { data, tokensUsed, promptTokens, outputTokens };
}

// ============================================
// Chat Calls (Flash Model)
// ============================================

export async function callChat(
  systemPrompt: string,
  messages: Array<{ role: 'user' | 'model'; content: string }>,
  userMessage: string
): Promise<GeminiResponse<string>> {
  const model = getFlashModel();

  // Build history
  const history = [
    {
      role: 'user' as const,
      parts: [{ text: systemPrompt }],
    },
    {
      role: 'model' as const,
      parts: [{ text: 'Got it, boss. Ready to help with the build.' }],
    },
    ...messages.map((m) => ({
      role: m.role as 'user' | 'model',
      parts: [{ text: m.content }],
    })),
  ];

  const chat = model.startChat({ history });
  const result = await chat.sendMessage(userMessage);
  const response = result.response;
  const text = response.text();

  const usageMetadata = response.usageMetadata;
  const promptTokens = usageMetadata?.promptTokenCount;
  const outputTokens = usageMetadata?.candidatesTokenCount;
  const tokensUsed = usageMetadata
    ? (promptTokens || 0) + (outputTokens || 0)
    : estimateTokensForText(systemPrompt + userMessage + text);

  return { data: text, tokensUsed, promptTokens, outputTokens };
}

// ============================================
// Utilities
// ============================================

export function estimateTokensForText(text: string): number {
  // Rough estimate: ~4 chars per token
  return Math.ceil(text.length / 4);
}

export class GeminiError extends Error {
  constructor(
    message: string,
    public step?: string
  ) {
    super(message);
    this.name = 'GeminiError';
  }
}
