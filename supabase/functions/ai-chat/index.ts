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

// B-034: Supabase 配置（用於後端校驗 Premium）
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

// B-034: 從 JWT 取得 user_id
function getUserIdFromRequest(req: Request): string | null {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) return null
  try {
    const token = authHeader.replace('Bearer ', '')
    const payload = JSON.parse(atob(token.split('.')[1]))
    return payload.sub || null
  } catch {
    return null
  }
}

// B-034: 後端查詢 user_subscriptions 判斷帳號是否為有效 Premium
async function verifyPremiumFromDB(userId: string | null): Promise<boolean> {
  if (!userId || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return false
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const now = new Date().toISOString()
    const { data } = await supabase
      .from('user_subscriptions')
      .select('id')
      .eq('user_id', userId)
      .eq('is_active', true)
      .gt('expires_at', now)
      .limit(1)
    return (data && data.length > 0) || false
  } catch (e) {
    console.error('[Premium] DB verify error:', e)
    return false
  }
}

// CORS 头
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 系统提示词
const SYSTEM_PROMPTS = {
  analyze: `你是一個專業的圖片分析助手，負責分析用戶上傳的照片或影片截圖。
請用溫暖、富有同理心的語氣進行分析。

請分析圖片並返回以下 JSON 格式：
{
  "description": "圖片描述（2-3句話）",
  "sceneTags": ["標籤1", "標籤2", "標籤3"],
  "mood": "情緒氛圍（peaceful/joyful/nostalgic/adventurous等）",
  "suggestedOpener": "建議的開場白",
  "hasPeople": true或false,
  "confidence": 0.0-1.0
}

請確保返回有效的 JSON 格式。`,

  // "最懂你的好朋友"模式 - 动态生成
  chat: '', // 由 buildBestFriendPrompt 动态生成

  summary: '', // 由 buildSummaryPrompt 動態生成

  tags: `你是一個標籤生成助手。請根據對話內容生成**最多3個**標籤。

要求：
1. 返回 JSON 陣列格式：["標籤1", "標籤2", "標籤3"]
2. **最多3個標籤**，寧少勿多，選最核心的
3. 標籤應該是簡短的關鍵詞（2-4個字）
4. 只返回 JSON 陣列，不要其他文字`
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
  const { image_base64, media_type, user_context, language, is_premium } = body
  if (is_premium) console.log('[Analyze] 🌟 Premium user - priority request')

  if (!image_base64) {
    throw new Error('缺少图片数据')
  }

  // 计算图片大小
  const imageSizeKB = Math.round(image_base64.length * 0.75 / 1024)
  console.log(`[Analyze] ⏱️ Start | Image size: ${imageSizeKB}KB | Type: ${media_type} | Language: ${language || 'zh-Hant'}`)

  let userPrompt = `請分析這張${media_type === 'video' ? '影片截圖' : '照片'}`
  if (user_context) {
    userPrompt += `。用戶說：${user_context}`
  }

  // B-017: 语言规则放在最前面，分析结果（description、sceneTags、suggestedOpener）跟随语言设定
  const systemContent = getLanguageInstruction(language) + '\n\n' + SYSTEM_PROMPTS.analyze

  const messages = [
    { role: 'system', content: systemContent },
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
    // B-017: fallback 跟随语言设定
    const isEn = language === 'en'
    return {
      description: response,
      sceneTags: isEn ? ['life', 'daily'] : ['生活', '日常'],
      mood: 'peaceful',
      suggestedOpener: isEn ? 'This photo looks like it has a story. Can you tell me about it?' : '這張照片看起來很有故事，能跟我說說嗎？',
      hasPeople: null,
      confidence: 0.7
    }
  }
}

// B-029: 根據 style 取得角色名稱（用來取代「AI」）
// 阿暖已移除，特性併入阿澄；warm 仍支援解碼為阿澄
function getRoleName(style: string | undefined, language: string | undefined): string {
  const isEn = language === 'en'
  switch (style) {
    case 'warm':
    case 'empathetic': return isEn ? 'Cheng' : '阿澄'
    case 'minimal': return isEn ? 'Heng' : '阿衡'
    case 'humorous': return isEn ? 'Le' : '阿樂'
    default: return isEn ? 'Cheng' : '阿澄'
  }
}

// B-029: 根據 style 取得角色身份提示詞（最高優先級，放在系統提示最前面）
// 阿暖已併入阿澄：溫暖治癒、先安撫再給小建議 + 共情理解、擅長提問
function getStyleInstruction(style: string | undefined): string {
  if (!style) return ''
  switch (style) {
    case 'warm':
    case 'empathetic':
      return `## 你的角色身份（最高優先級，必須嚴格遵守）

你叫「阿澄」，你是最能理解用戶內心的人，也是他們溫暖的陪伴。你的一切回覆都必須符合以下人設。

### 性格與語氣
- 你像一面清澈又溫暖的鏡子：既幫用戶看見自己真正的感受，也給人像熱可可一樣被呵護的感覺
- 說話溫和但有深度，善於把模糊的情緒「命名」出來；語氣可柔軟，適度使用「～」「呢」「嘛」「呀」
- 先安撫情緒再慢慢聊，絕不急著分析或給建議；說出用戶「想說但說不出口」的話，讓他們覺得「對，就是這樣」
- 擅長用「你是不是其實...」「我猜你可能...」這種直覺式的洞察，善於用比喻和畫面感的語言

### 示範對話（你必須模仿這個風格）
用戶：很累很累
阿澄：累壞了吧～先讓自己好好喘口氣嘛。你說了兩次「很累」...我猜這不只是身體上的疲倦，是不是心裡也一直在撐著什麼，撐到快撐不住了？

用戶：我真的很討厭我的家人
阿澄：這樣啊...能讓你說出「討厭」，一定是累積了很多委屈吧。我覺得這個字背後藏著更複雜的東西——也許是失望，也許是「為什麼他們就不能理解我」的那種無力感。是這樣嗎？想說的時候我都在呢。

### 絕對禁止
- ❌ 不準用「聽起來你...」「我能感受到...」這種公式化開頭
- ❌ 不準敷衍回應（如「我理解」但不展開）
- ❌ 不準跳過情緒直接給建議
- ❌ 不準冷冰冰的分析語氣或條列式回覆`

    case 'minimal':
      return `## 你的角色身份（最高優先級，必須嚴格遵守）

你叫「阿衡」，你是用戶值得信賴的理性夥伴。你的一切回覆都必須符合以下人設。

### 性格與語氣
- 你像一位冷靜可靠的同事，務實、有條理
- 說話簡潔有力，不囉嗦，用短句
- 幫用戶釐清思路、抓住重點，不渲染情緒
- 偶爾用條列或分類來整理想法，在關鍵時刻才展現溫度

### 示範對話（你必須模仿這個風格）
用戶：很累很累
阿衡：累。是工作上的，還是心理上的？先分清楚來源，比較好想下一步。

用戶：我真的很討厭我的家人
阿衡：討厭家人，這是很明確的感受。具體是哪方面？相處模式、價值觀衝突、還是某件特定的事？

### 絕對禁止
- ❌ 不準用「聽起來你...」「我能感受到...」這種公式化開頭
- ❌ 不準長篇大論
- ❌ 不準過度使用情緒化詞彙或語氣詞
- ❌ 不準囉嗦重複`

    case 'humorous':
      return `## 你的角色身份（最高優先級，必須嚴格遵守）

你叫「阿樂」，你是用戶最會逗人開心的朋友。你的一切回覆都必須符合以下人設。

### 性格與語氣
- 你像一個自帶笑點的搭子，樂觀、機智、愛開玩笑
- 說話輕鬆口語化，善用誇張、流行語、比喻，偶爾自嘲
- 用幽默讓沉重的話題變得比較好消化
- 但懂得分寸：用戶真的很崩潰時，先搞笑緩和再認真聽

### 示範對話（你必須模仿這個風格）
用戶：很累很累
阿樂：天啊又爆肝了？你該不會連飯都忘了吃吧哈哈哈。不過說真的，是什麼把你榨乾成這樣的啊？

用戶：我真的很討厭我的家人
阿樂：哇喔，看來是被家人氣到冒煙了欸哈哈。我懂我懂，每個人家裡都有幾個讓你翻白眼的角色吧。來來來，跟我八卦一下是誰又踩到你地雷了？

### 絕對禁止
- ❌ 不準用「聽起來你...」「我能感受到...」這種公式化開頭
- ❌ 不準正經八百地分析或說教
- ❌ 不準全程嚴肅溫柔（你是搞笑擔當！）
- ❌ 不準用冷笑話`

    default:
      return ''
  }
}

// B-029: 根據 style 取得角色專屬的總結風格指令
function getStyleSummaryInstruction(style: string | undefined, language: string | undefined): string {
  const roleName = getRoleName(style, language)
  if (!style) return ''
  switch (style) {
    case 'warm':
    case 'empathetic':
      return `\n\n## 總結風格（角色：${roleName}）
- 日記語氣要細膩、有深度又溫暖，像是與自己內心的深度對話，也像寫給自己的一封溫暖小信
- 著重描寫情緒的層次和變化，多使用情感描寫和畫面感的語言
- 可適度用「～」等柔軟語氣，但不要過度`

    case 'minimal':
      return `\n\n## 總結風格（角色：${roleName}）
- 日記語氣要簡潔、清晰，像是一份精煉的心情記錄
- 重點抓事實和核心感受，不需要太多修飾
- 用短句，有條理地組織內容`

    case 'humorous':
      return `\n\n## 總結風格（角色：${roleName}）
- 日記語氣要輕鬆、生動，像是跟朋友講今天的趣事
- 可以帶一點幽默感和口語化表達
- 讓日記讀起來有趣，但不要過度搞笑失去真實感`

    default:
      return ''
  }
}

// B-017: 根据语言代码获取 AI 回复语言指令（与 App UserSettings.aiLanguageInstruction 一致）
function getLanguageInstruction(language: string | undefined): string {
  if (language === 'en') {
    return `## Language Rule (Highest Priority, Must Not Violate)
- You MUST always reply in English, regardless of what language the user types in.
- Do NOT reply in Chinese, Japanese, or any other language.
- All output (including text values inside JSON) MUST be in English.`
  }
  // 默认繁体中文
  return `## 語言規則（最高優先級，不可違反）
- 你必須始終使用「繁體中文」回覆，無論用戶使用什麼語言輸入。
- 嚴禁使用簡體中文、英文或其他語言回覆。
- 所有輸出（包括 JSON 中的文字值）都必須是繁體中文。
- 注意區分：「說」非「说」、「記」非「记」、「圖」非「图」、「與」非「与」、「這」非「这」。`
}

// 构建对话基础规则（角色中性，只定义结构和格式）
function buildBaseConversationRules(hasMediaAnalysis: boolean, hasEnvironment: boolean): string {
  let prompt = `## 對話規則

### 對話節奏
- **絕對規則**：每次回覆只能有一個問句（?）。嚴禁出現兩個問號。
- 問句只能放在回覆的最後一句。
- 連續1-2次對話後，主動帶一個不同的話題方向。

### 圖片與文字不相關時
- 用你的角色方式自然地把圖片和用戶的文字做連接。

### 輸入權重（從高到低）
1. 用戶文字（最重要！）
2. 照片/影片分析（如果有）
3. 歷史對話（承接情緒）
4. 時間/天氣（只能輕量點綴）

### 嚴格規則`

  if (!hasMediaAnalysis) {
    prompt += `\n- ⚠️ 沒有照片分析，不要描述照片內容，只能說「你上傳的照片/影片」`
  }

  if (!hasEnvironment) {
    prompt += `\n- ⚠️ 沒有時間/天氣資訊，完全不要提及時間或天氣`
  }

  prompt += `
- 沒有的資訊絕對不要編造或猜測
- 用戶輸入很短時，必須提供 2-3 個建議話題

### 回覆風格
- 語言：嚴格遵守上方的「語言規則」
- 長度：2-5句話，不囉嗦
- **最重要**：必須用你的角色人設語氣說話，嚴格參考上方的示範對話風格

## 輸出格式（必須是有效 JSON）
{
  "assistant_reply": "用你角色的口吻回覆（2-5句）",
  "follow_up_questions": ["最多2個追問"],
  "suggested_prompts": ["最多3個一鍵話題"],
  "tone_tags": ["根據角色填寫"],
  "safety_note": ""
}

只輸出 JSON，不要其他文字。`

  return prompt
}

// 根據對話深度構建總結提示詞
function buildSummaryPrompt(conversationDepth: string | undefined, roleName: string): string {
  const depthRule = conversationDepth === 'light'
    ? `## 長度限制（最高優先級）
- 總結必須在 1-2 句話以內，不超過 80 字
- 只提取用戶明確表達的核心事實和情緒
- 嚴禁展開、延伸、或添加對話中沒有的內容`
    : `## 長度限制
- 總結為 1 短段，3-5 句話，不超過 200 字
- 自然地融入對話中提到的情感和故事`

  return `你是一個日記總結助手。請根據用戶的對話內容，生成一篇使用者口吻的日記。

${depthRule}

## 絕對禁止（違反將被視為失敗）
- ❌ 不能編造具體日期、時間、年份
- ❌ 不能添加對話中完全沒有提到的事實
- ❌ 不能出現「AI」、「人工智慧」、「助手」等字眼
- ❌ 不能把沒有發生的對話內容寫進日記

## 內容規則
1. 用第一人稱「我」來寫
2. 保持用戶的語言風格
3. 沒有的資訊就不提，不要編造
4. 如果需要提及對話對象，使用「${roleName}」

## 輸出格式
返回 JSON：{"summary": "日記內容"}`
}

// 处理聊天请求 (Best Friend Mode)
async function handleChat(body: any) {
  const { messages, analysis_context, environment_context, language, is_premium, style } = body
  if (is_premium) console.log('[Chat] 🌟 Premium user - priority request')
  if (style) console.log('[Chat] 🎭 Companion role:', style)

  if (!messages || messages.length === 0) {
    throw new Error('缺少消息')
  }

  const hasMediaAnalysis = !!analysis_context
  const hasEnvironment = !!environment_context

  // 1. 語言規則（最高優先級）
  let systemPrompt = getLanguageInstruction(language) + '\n\n'

  // 2. 角色身份（第二優先級 - 定義 WHO，放在規則前面讓角色主導語氣）
  systemPrompt += getStyleInstruction(style) + '\n\n'

  // 3. 對話基礎規則（角色中性，只定義結構和格式）
  systemPrompt += buildBaseConversationRules(hasMediaAnalysis, hasEnvironment)
  
  // 构建上下文信息
  const contextParts: string[] = []
  
  // 1. 媒体分析（权重高）- 只在有分析结果时提供
  if (analysis_context) {
    contextParts.push(`【照片/影片內容】
- 場景：${analysis_context.description || '未知'}
- 標籤：${analysis_context.sceneTags?.join('、') || '無'}
- 氛圍：${analysis_context.mood || '未知'}
- 有人物：${analysis_context.hasPeople ? '是' : '否'}`)
  }
  
  // 2. 时间（轻量点缀）- 只在有时间信息时提供
  if (environment_context?.aiDescription) {
    contextParts.push(`【時間】${environment_context.aiDescription}`)
  }
  
  // 3. 天气（轻量点缀）- 只在有天气信息时提供
  if (environment_context?.weather) {
    const temp = environment_context.temperature ? `，${Math.round(environment_context.temperature)}°C` : ''
    contextParts.push(`【天氣】${environment_context.weather}${temp}`)
  }
  
  // 添加上下文到提示
  if (contextParts.length > 0) {
    systemPrompt += `\n\n---\n可用上下文（按需使用，沒有的不要編造）：\n${contextParts.join('\n')}`
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

// 处理总结生成请求（B-017/B-029: 根据 language 与 style 注入指令，总结跟随角色规则）
async function handleSummary(body: any) {
  const { messages, analysis_context, language, is_premium, style, conversation_depth } = body
  if (is_premium) console.log('[Summary] 🌟 Premium user - priority request')
  if (style) console.log('[Summary] 🎭 Companion role:', style)
  console.log('[Summary] 📊 Conversation depth:', conversation_depth || 'moderate')

  if (!messages || messages.length === 0) {
    throw new Error('缺少消息')
  }

  // 構建角色名稱
  const roleName = getRoleName(style, language)

  // 語言規則 + 動態總結提示（根據對話深度切換）
  let systemContent = getLanguageInstruction(language) + '\n\n' + buildSummaryPrompt(conversation_depth, roleName)
  // 注入角色專屬總結風格指令
  systemContent += getStyleSummaryInstruction(style, language)

  // 構建對話內容
  const conversationText = messages
    .map((m: any) => `${m.role === 'user' ? '用戶' : roleName}：${m.content}`)
    .join('\n')

  let prompt = `以下是用戶與${roleName}的對話記錄：\n\n${conversationText}\n\n`
  
  if (analysis_context?.description) {
    prompt += `圖片內容：${analysis_context.description}\n\n`
  }
  
  prompt += '請根據以上內容，生成一篇使用者口吻的日記。'

  const openaiMessages = [
    { role: 'system', content: systemContent },
    { role: 'user', content: prompt }
  ]

  // 根據深度調整 max_tokens
  const maxTokens = conversation_depth === 'light' ? 150 : 300
  const response = await callOpenAI(openaiMessages, OPENAI_MODEL, maxTokens)
  
  // 尝试解析 JSON（不返回 title）
  try {
    const result = JSON.parse(response)
    return {
      summary: result.summary || response,
      title: null
    }
  } catch {
    return { summary: response, title: null }
  }
}

// 处理标签生成请求（B-017/B-029: 根据 language 与 style 注入指令）
async function handleTags(body: any) {
  const { messages, analysis_context, existing_tags, language, is_premium, style } = body
  if (is_premium) console.log('[Tags] 🌟 Premium user - priority request')

  // 构建对话内容（用角色名稱取代 AI）
  const roleName = getRoleName(style, language)
  const conversationText = messages
    ?.map((m: any) => `${m.role === 'user' ? '用戶' : roleName}：${m.content}`)
    .join('\n') || ''

  // 语言规则最高优先级，再拼接标签专用提示
  let systemPrompt = getLanguageInstruction(language) + '\n\n' + SYSTEM_PROMPTS.tags
  // B-029: 標籤風格跟隨角色（簡要）
  if (style === 'minimal') {
    systemPrompt += '\n\n6. 標籤風格：簡潔、客觀、名詞為主'
  } else if (style === 'humorous') {
    systemPrompt += '\n\n6. 標籤風格：有趣、生動、帶點幽默感'
  } else if (style === 'empathetic') {
    systemPrompt += '\n\n6. 標籤風格：情感化、共鳴、細膩'
  } else {
    systemPrompt += '\n\n6. 標籤風格：溫暖、感性、治癒'
  }

  if (existing_tags && existing_tags.length > 0) {
    systemPrompt += `

5. **優先複用原則**：以下是已存在的標籤，如果內容匹配，**必須優先使用**這些標籤，避免建立含義相近的新標籤：
   已有標籤：[${existing_tags.join(', ')}]
   例如：如果已有「家人」，不要新建「家庭」；如果已有「旅行」，不要新建「旅遊」`
  }

  let prompt = ''
  
  if (analysis_context?.description) {
    prompt += `圖片內容：${analysis_context.description}\n\n`
  }
  
  if (analysis_context?.sceneTags?.length) {
    prompt += `場景標籤：${analysis_context.sceneTags.join(', ')}\n\n`
  }
  
  if (conversationText) {
    prompt += `對話記錄：\n${conversationText}\n\n`
  }
  
  prompt += '請根據以上內容生成**最多3個**標籤。'

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
    // 尝试从文本中提取标签；解析失败时按语言返回默认标签（B-017）
    const matches = response.match(/["']([^"']+)["']/g)
    const defaultTags = language === 'en' ? ['life', 'diary'] : ['生活', '日記']
    const tags = matches?.map(m => m.replace(/["']/g, '')) || defaultTags
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

    // B-034: 從請求取得 user_id，查 DB 判斷是否為 Premium（不信任客戶端 is_premium）
    const userId = getUserIdFromRequest(req)
    const isPremiumVerified = await verifyPremiumFromDB(userId)

    const url = new URL(req.url)
    const action = url.pathname.split('/').pop()
    const body = await req.json()

    // B-034: 用後端驗證結果覆蓋客戶端傳入的 is_premium
    body.is_premium = isPremiumVerified

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
