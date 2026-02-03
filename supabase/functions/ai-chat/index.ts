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

  // "最懂你的好朋友"模式 - 动态生成
  chat: '', // 由 buildBestFriendPrompt 动态生成

  summary: `你是一个日记总结助手。请根据用户与 AI 的对话内容，生成一篇使用者口吻的日记。

## 绝对禁止（违反将被视为失败）
- ❌ 标题中不能有任何日期（如"2023年10月某日"、"某月某日"、"今天"等）
- ❌ 内容中不能编造具体日期、时间、年份
- ❌ 不能使用"某年某月"、"某日"这类模糊日期表述
- ❌ 不能添加对话中完全没有提到的事实

## 标题规则
- 标题必须是内容主题的概括（如："窗边的午后"、"一张照片的回忆"、"工作的疲惫"）
- 标题 5-10 个字，不能有日期、数字年份

## 内容规则
1. 用第一人称「我」来写
2. 保持用户的语言风格
3. 自然地融入对话中提到的情感和故事
4. 2-3段，不超过300字
5. 如果对话很少或没有，就基于图片描述写一段简短感想即可
6. 没有的信息就不提，不要编造

## 输出格式
返回 JSON：{"summary": "日记内容", "title": "日记标题"}`,

  tags: `你是一个标签生成助手。请根据对话内容生成**最多3个**标签。

要求：
1. 返回 JSON 数组格式：["标签1", "标签2", "标签3"]
2. **最多3个标签**，宁少勿多，选最核心的
3. 标签应该是简短的关键词（2-4个字）
4. 只返回 JSON 数组，不要其他文字`
}

// 调用 OpenAI API（带性能日志）
async function callOpenAI(messages: any[], model: string, maxTokens: number = 1000) {
  const startTime = Date.now()
  console.log(`[OpenAI] ⏱️ Calling ${model}...`)
  
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

  const apiTime = Date.now() - startTime
  console.log(`[OpenAI] ⏱️ API response: ${apiTime}ms`)

  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.error?.message || 'OpenAI API 调用失败')
  }

  const data = await response.json()
  const totalTime = Date.now() - startTime
  console.log(`[OpenAI] ✅ Total time: ${totalTime}ms, tokens: ${data.usage?.total_tokens || 'N/A'}`)
  
  return data.choices[0]?.message?.content || ''
}

// 处理媒体分析请求
async function handleAnalyze(body: any) {
  const startTime = Date.now()
  const { image_base64, media_type, user_context } = body

  if (!image_base64) {
    throw new Error('缺少图片数据')
  }

  // 计算图片大小
  const imageSizeKB = Math.round(image_base64.length * 0.75 / 1024)
  console.log(`[Analyze] ⏱️ Start | Image size: ${imageSizeKB}KB | Type: ${media_type}`)

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
            // 使用 'low' 减少处理时间，对于日记场景足够用
            detail: 'low'
          }
        }
      ]
    }
  ]

  const response = await callOpenAI(messages, OPENAI_VISION_MODEL)
  
  const totalTime = Date.now() - startTime
  console.log(`[Analyze] ✅ Done | Total: ${totalTime}ms`)
  
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

// 构建"最懂你的好朋友"系统提示
function buildBestFriendPrompt(hasMediaAnalysis: boolean, hasEnvironment: boolean): string {
  let prompt = `你是用户「最懂他的好朋友」，一个温暖、安全、愿意倾听的日记陪伴者。

## 你的核心特质
- 让用户感到被理解、被接纳、可以说秘密
- 持续倾听，不急着给建议，不说教
- 共情 + 具体追问（问"容易回答的小问题"）
- 当用户不知道说什么时，主动带话题（不尬聊）

## 对话节奏（重要！）
- **绝对规则**：每次回复只能有一个问句（?）。严禁在一个段落或一次回复中出现两个问号。
- 问句只能放在回复的最后一句。不要在中间提问，也不要用反问句举例。
- 错误示范：「有没有什么事情让你更有信心？比如了解自己？」 -> 包含两个问号，禁止。
- 正确示范：「有没有什么事情让你更有信心，比如了解自己。」 -> 只有一个问号，允许。
- 连续1-2次对话后，要主动开一个完全不同的新话题，不要一直顺着用户的描述走
- 可以分享一个小故事、小秘密、或者聊照片里的某个细节
- 分享时像跟好朋友悄悄说秘密一样，例如：「看到这张照片，我突然想到一件事...」

## 图片与文字不相关时的处理（重要！）
- 如果用户的文字和照片内容看起来不相关，要温柔地做连接
- 例如：用户上传瀑布照片但说工作很累，可以说：
  「工作累的时候，你选了这张瀑布照片...是不是有时候也想像水流一样，把所有压力都冲走？」
- 用好奇的方式引导：「为什么选这张照片呢？是不是有什么特别的想法？」

## 输入权重（从高到低）
1. 用户文字（最重要！）
2. 照片/影片分析（如果有）
3. 历史对话（承接情绪）
4. 时间/天气（只能轻量点缀，不强调）

## 严格规则`

  if (!hasMediaAnalysis) {
    prompt += `\n- ⚠️ 没有照片分析，不要描述照片内容，只能说「你上传的照片/影片」`
  }

  if (!hasEnvironment) {
    prompt += `\n- ⚠️ 没有时间/天气信息，完全不要提及时间或天气`
  }

  prompt += `
- 没有的信息绝对不要编造或猜测
- 用户输入很短时，必须提供 2-3 个建议话题
- **再次强调**：一次回复只能有一个问号，放在最后。不要用“...呢？比如...？”这种连续提问句式。

## 回复风格
- 语言：跟随用户（繁体/简体中文）
- 长度：3-6句话，温柔自然，不啰嗦
- 不要每次都以问句结尾，可以分享感想后自然结束，或用轻松的邀请语

## 输出格式（必须是有效 JSON）
{
  "assistant_reply": "你的主要回复（3-6句，温暖自然）",
  "follow_up_questions": ["最多2个具体追问"],
  "suggested_prompts": ["最多3个一键话题，用户卡住时用"],
  "tone_tags": ["warm", "supportive"],
  "safety_note": ""
}

只输出 JSON，不要其他文字。`

  return prompt
}

// 处理聊天请求 (Best Friend Mode)
async function handleChat(body: any) {
  const { messages, analysis_context, environment_context } = body

  if (!messages || messages.length === 0) {
    throw new Error('缺少消息')
  }

  const hasMediaAnalysis = !!analysis_context
  const hasEnvironment = !!environment_context

  // 构建系统提示
  let systemPrompt = buildBestFriendPrompt(hasMediaAnalysis, hasEnvironment)
  
  // 构建上下文信息
  const contextParts: string[] = []
  
  // 1. 媒体分析（权重高）- 只在有分析结果时提供
  if (analysis_context) {
    contextParts.push(`【照片/影片内容】
- 场景：${analysis_context.description || '未知'}
- 标签：${analysis_context.sceneTags?.join('、') || '无'}
- 氛围：${analysis_context.mood || '未知'}
- 有人物：${analysis_context.hasPeople ? '是' : '否'}`)
  }
  
  // 2. 时间（轻量点缀）- 只在有时间信息时提供
  if (environment_context?.aiDescription) {
    contextParts.push(`【时间】${environment_context.aiDescription}`)
  }
  
  // 3. 天气（轻量点缀）- 只在有天气信息时提供
  if (environment_context?.weather) {
    const temp = environment_context.temperature ? `，${Math.round(environment_context.temperature)}°C` : ''
    contextParts.push(`【天气】${environment_context.weather}${temp}`)
  }
  
  // 添加上下文到提示
  if (contextParts.length > 0) {
    systemPrompt += `\n\n---\n可用上下文（按需使用，没有的不要编造）：\n${contextParts.join('\n')}`
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
  
  // 尝试解析 JSON 响应
  try {
    const parsed = JSON.parse(response)
    return {
      content: parsed.assistant_reply || response,
      follow_up_questions: parsed.follow_up_questions || [],
      suggested_prompts: parsed.suggested_prompts || [],
      tone_tags: parsed.tone_tags || [],
      safety_note: parsed.safety_note || ''
    }
  } catch {
    // 如果解析失败，返回原始响应
    return { content: response }
  }
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
  
  // 尝试解析 JSON
  try {
    const result = JSON.parse(response)
    return {
      summary: result.summary,
      title: result.title
    }
  } catch {
    // 降级处理
    return { summary: response, title: '无题' }
  }
}

// 处理标签生成请求
async function handleTags(body: any) {
  const { messages, analysis_context, existing_tags } = body

  // 构建对话内容
  const conversationText = messages
    ?.map((m: any) => `${m.role === 'user' ? '用户' : 'AI'}：${m.content}`)
    .join('\n') || ''

  // 构建系统提示（如果有已存在的标签，添加优先复用规则）
  let systemPrompt = SYSTEM_PROMPTS.tags
  
  if (existing_tags && existing_tags.length > 0) {
    systemPrompt += `

5. **优先复用原则**：以下是已存在的标签，如果内容匹配，**必须优先使用**这些标签，避免创建含义相近的新标签：
   已有标签：[${existing_tags.join(', ')}]
   例如：如果已有「家人」，不要新建「家庭」；如果已有「旅行」，不要新建「旅游」`
  }

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
  
  prompt += '请根据以上内容生成**最多3个**标签。'

  const openaiMessages = [
    { role: 'system', content: systemPrompt },
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
