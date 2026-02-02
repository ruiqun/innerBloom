// Supabase Edge Function: AI Chat 代理
// 用于安全地调用 OpenAI API，不暴露 API Key 给客户端
//
// 功能：
// - 媒体分析 (F-003)
// - 聊天对话 (F-004)
// - 总结生成 (F-005)
// - 标签生成 (F-005)
//
// 部署命令：
// supabase functions deploy ai-chat --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// 从环境变量获取配置
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')
const OPENAI_MODEL = Deno.env.get('OPENAI_MODEL') || 'gpt-4o-mini'
const OPENAI_VISION_MODEL = Deno.env.get('OPENAI_VISION_MODEL') || 'gpt-4o-mini'

// CORS 头
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 系统提示词
const SYSTEM_PROMPTS = {
  analyze: `你是一个专业的图片分析助手，负责分析用户上传的照片或视频截图。
请用温暖、富有同理心的语气进行分析。

请分析图片并返回以下 JSON 格式：
{
  "description": "图片描述（2-3句话）",
  "sceneTags": ["标签1", "标签2", "标签3"],
  "mood": "情绪氛围（peaceful/joyful/nostalgic/adventurous等）",
  "suggestedOpener": "建议的开场白",
  "hasPeople": true或false,
  "confidence": 0.0-1.0
}

请确保返回有效的 JSON 格式。`,

  chat: `你是一个温暖、善解人意的日记陪伴助手。用户正在通过照片或视频记录生活，你的任务是：
1. 用温暖、富有同理心的语气与用户对话
2. 引导用户分享照片背后的故事和感受
3. 适时给予情感支持和鼓励
4. 保持对话自然流畅，像朋友一样交流

回复要求：
- 使用繁体中文或简体中文（跟随用户的语言）
- 回复简洁，通常2-4句话
- 多用问句引导用户继续分享
- 避免说教或给太多建议`,

  summary: `你是一个日记总结助手。请根据用户与 AI 的对话内容，生成一篇使用者口吻的日记。

要求：
1. 用第一人称「我」来写
2. 保持用户的语言风格
3. 自然地融入对话中提到的情感和故事
4. 2-3段，不超过300字
5. 不要添加对话中没有提到的内容`,

  tags: `你是一个标签生成助手。请根据对话内容生成3-8个标签。

要求：
1. 返回 JSON 数组格式：["标签1", "标签2", ...]
2. 标签应该是简短的关键词
3. 包括：主题（如旅行、美食）、情绪（如开心、怀念）、人物关系（如朋友、家人）
4. 只返回 JSON 数组，不要其他文字`
}

// 调用 OpenAI API
async function callOpenAI(messages: any[], model: string, maxTokens: number = 1000) {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages,
      max_tokens: maxTokens,
      temperature: 0.7,
    }),
  })

  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.error?.message || 'OpenAI API 调用失败')
  }

  const data = await response.json()
  return data.choices[0]?.message?.content || ''
}

// 处理媒体分析请求
async function handleAnalyze(body: any) {
  const { image_base64, media_type, user_context } = body

  if (!image_base64) {
    throw new Error('缺少图片数据')
  }

  let userPrompt = `请分析这张${media_type === 'video' ? '视频截图' : '照片'}`
  if (user_context) {
    userPrompt += `。用户说：${user_context}`
  }

  const messages = [
    { role: 'system', content: SYSTEM_PROMPTS.analyze },
    {
      role: 'user',
      content: [
        { type: 'text', text: userPrompt },
        {
          type: 'image_url',
          image_url: {
            url: `data:image/jpeg;base64,${image_base64}`,
            detail: 'auto'
          }
        }
      ]
    }
  ]

  const response = await callOpenAI(messages, OPENAI_VISION_MODEL)
  
  // 尝试解析 JSON
  try {
    return JSON.parse(response)
  } catch {
    return {
      description: response,
      sceneTags: ['生活', '日常'],
      mood: 'peaceful',
      suggestedOpener: '这张照片看起来很有故事，能跟我说说吗？',
      hasPeople: null,
      confidence: 0.7
    }
  }
}

// 处理聊天请求
async function handleChat(body: any) {
  const { messages, analysis_context } = body

  if (!messages || messages.length === 0) {
    throw new Error('缺少消息')
  }

  // 构建系统提示
  let systemPrompt = SYSTEM_PROMPTS.chat
  
  if (analysis_context) {
    systemPrompt += `\n\n关于用户上传的媒体内容：
- 场景描述：${analysis_context.description || '未知'}
- 场景标签：${analysis_context.sceneTags?.join(', ') || '未知'}
- 情绪氛围：${analysis_context.mood || '未知'}
- 是否有人物：${analysis_context.hasPeople ? '是' : '否'}`
  }

  // 转换消息格式
  const openaiMessages = [
    { role: 'system', content: systemPrompt },
    ...messages.map((m: any) => ({
      role: m.role === 'user' ? 'user' : 'assistant',
      content: m.content
    }))
  ]

  const response = await callOpenAI(openaiMessages, OPENAI_MODEL)
  
  return { content: response }
}

// 处理总结生成请求
async function handleSummary(body: any) {
  const { messages, analysis_context } = body

  if (!messages || messages.length === 0) {
    throw new Error('缺少消息')
  }

  // 构建对话内容
  const conversationText = messages
    .map((m: any) => `${m.role === 'user' ? '用户' : 'AI'}：${m.content}`)
    .join('\n')

  let prompt = `以下是用户与 AI 的对话记录：\n\n${conversationText}\n\n`
  
  if (analysis_context?.description) {
    prompt += `图片内容：${analysis_context.description}\n\n`
  }
  
  prompt += '请根据以上内容，生成一篇使用者口吻的日记。'

  const openaiMessages = [
    { role: 'system', content: SYSTEM_PROMPTS.summary },
    { role: 'user', content: prompt }
  ]

  const response = await callOpenAI(openaiMessages, OPENAI_MODEL, 500)
  
  return { summary: response }
}

// 处理标签生成请求
async function handleTags(body: any) {
  const { messages, analysis_context } = body

  // 构建对话内容
  const conversationText = messages
    ?.map((m: any) => `${m.role === 'user' ? '用户' : 'AI'}：${m.content}`)
    .join('\n') || ''

  let prompt = ''
  
  if (analysis_context?.description) {
    prompt += `图片内容：${analysis_context.description}\n\n`
  }
  
  if (analysis_context?.sceneTags?.length) {
    prompt += `场景标签：${analysis_context.sceneTags.join(', ')}\n\n`
  }
  
  if (conversationText) {
    prompt += `对话记录：\n${conversationText}\n\n`
  }
  
  prompt += '请根据以上内容生成标签。'

  const openaiMessages = [
    { role: 'system', content: SYSTEM_PROMPTS.tags },
    { role: 'user', content: prompt }
  ]

  const response = await callOpenAI(openaiMessages, OPENAI_MODEL, 200)
  
  // 尝试解析 JSON
  try {
    const tags = JSON.parse(response)
    return { tags: Array.isArray(tags) ? tags : [] }
  } catch {
    // 尝试从文本中提取标签
    const matches = response.match(/["']([^"']+)["']/g)
    const tags = matches?.map(m => m.replace(/["']/g, '')) || ['生活', '日记']
    return { tags }
  }
}

// 主处理函数
serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 检查 API Key 配置
    if (!OPENAI_API_KEY) {
      throw new Error('服务未配置，请联系管理员')
    }

    const url = new URL(req.url)
    const action = url.pathname.split('/').pop()
    const body = await req.json()

    let result

    switch (action) {
      case 'analyze':
        result = await handleAnalyze(body)
        break
      case 'chat':
        result = await handleChat(body)
        break
      case 'summary':
        result = await handleSummary(body)
        break
      case 'tags':
        result = await handleTags(body)
        break
      default:
        throw new Error(`未知操作: ${action}`)
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error:', error.message)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
