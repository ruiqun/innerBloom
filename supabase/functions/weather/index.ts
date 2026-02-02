// Supabase Edge Function: 天气代理
// 自动选择供应商：QWeather（中国）/ WeatherKit（海外）
//
// 部署命令：
// supabase functions deploy weather --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// 从环境变量获取 API Keys
const QWEATHER_HOST = Deno.env.get('QWEATHER_HOST') // 免费开发版使用自定义域名
const QWEATHER_API_KEY = Deno.env.get('QWEATHER_API_KEY') // 商业版使用 API Key
const WEATHERKIT_AUTH_KEY = Deno.env.get('WEATHERKIT_AUTH_KEY') // Apple WeatherKit JWT
const OPENWEATHER_API_KEY = Deno.env.get('OPENWEATHER_API_KEY')

// CORS 头
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 和风天气 API 基础 URL（免费开发版使用自定义域名）
const QWEATHER_BASE_URL = QWEATHER_HOST 
  ? `https://${QWEATHER_HOST}/v7`
  : 'https://devapi.qweather.com/v7'

// WeatherKit API 基础 URL
const WEATHERKIT_BASE_URL = 'https://weatherkit.apple.com/api/v1'

// 请求体类型
interface WeatherRequest {
  latitude: number
  longitude: number
  provider: 'qweather' | 'weatherkit'
}

// 响应体类型
interface WeatherResponse {
  currentTempC: number
  conditionText: string
  conditionIcon: string | null
  isRainingNow: boolean
  nextHourRainProbability: number | null
  nextHourPrecipMM: number | null
  source: string
}

// 和风天气处理
async function handleQWeather(lat: number, lon: number): Promise<WeatherResponse> {
  console.log(`[QWeather] Fetching weather for: ${lat}, ${lon}`)
  console.log(`[QWeather] Using host: ${QWEATHER_HOST || 'default'}, key: ${QWEATHER_API_KEY ? '✓' : '✗'}`)
  
  // 免费开发版需要：自定义域名 + API Key
  if (!QWEATHER_HOST || !QWEATHER_API_KEY) {
    console.warn('[QWeather] Missing host or API key, falling back to OpenWeather')
    return await handleOpenWeatherFallback(lat, lon)
  }
  
  // 构建 URL（免费开发版需要同时使用自定义域名和 API Key）
  const buildUrl = (endpoint: string) => {
    return `${QWEATHER_BASE_URL}/${endpoint}?location=${lon},${lat}&key=${QWEATHER_API_KEY}`
  }
  
  try {
    // 获取实时天气
    const nowUrl = buildUrl('weather/now')
    console.log(`[QWeather] Fetching: ${nowUrl.replace(QWEATHER_API_KEY || '', '***')}`)
    
    const nowResponse = await fetch(nowUrl)
    const nowData = await nowResponse.json()
    
    if (nowData.code !== '200') {
      console.error(`[QWeather] Now API error: ${nowData.code}`)
      throw new Error(`QWeather API error: ${nowData.code}`)
    }
    
    const now = nowData.now
    console.log(`[QWeather] Current weather: ${now.text}, ${now.temp}°C`)
    
    // 获取逐小时预报（用于下一小时降雨）
    let nextHourRainProb: number | null = null
    let nextHourPrecip: number | null = null
    
    try {
      const hourlyUrl = buildUrl('weather/24h')
      const hourlyResponse = await fetch(hourlyUrl)
      const hourlyData = await hourlyResponse.json()
      
      if (hourlyData.code === '200' && hourlyData.hourly?.length > 0) {
        const nextHour = hourlyData.hourly[0]
        nextHourRainProb = nextHour.pop ? parseInt(nextHour.pop) : null
        nextHourPrecip = nextHour.precip ? parseFloat(nextHour.precip) : null
        console.log(`[QWeather] Next hour: ${nextHourRainProb}% rain, ${nextHourPrecip}mm`)
      }
    } catch (e) {
      console.warn(`[QWeather] Hourly forecast failed: ${e}`)
    }
    
    // 判断是否下雨（根据天气代码或描述）
    const rainConditions = ['雨', '雪', '雷', '阵雨', 'rain', 'shower', 'drizzle']
    const isRaining = rainConditions.some(c => now.text.toLowerCase().includes(c)) ||
                      (now.precip && parseFloat(now.precip) > 0)
    
    return {
      currentTempC: parseFloat(now.temp),
      conditionText: now.text,
      conditionIcon: now.icon,
      isRainingNow: isRaining,
      nextHourRainProbability: nextHourRainProb,
      nextHourPrecipMM: nextHourPrecip,
      source: 'QWeather'
    }
  } catch (e) {
    console.error(`[QWeather] Error: ${e}`)
    return await handleOpenWeatherFallback(lat, lon)
  }
}

// WeatherKit 处理（Apple）
async function handleWeatherKit(lat: number, lon: number): Promise<WeatherResponse> {
  console.log(`[WeatherKit] Fetching weather for: ${lat}, ${lon}`)
  
  // 注意：WeatherKit 需要 Apple Developer 账号和 JWT Token
  // 这里提供一个简化的实现，实际需要配置正确的认证
  
  if (!WEATHERKIT_AUTH_KEY) {
    console.warn('[WeatherKit] Auth key not configured, using OpenWeather fallback')
    return await handleOpenWeatherFallback(lat, lon)
  }
  
  try {
    const url = `${WEATHERKIT_BASE_URL}/weather/zh_CN/${lat}/${lon}?dataSets=currentWeather,forecastHourly`
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${WEATHERKIT_AUTH_KEY}`,
      }
    })
    
    if (!response.ok) {
      console.warn(`[WeatherKit] API error: ${response.status}, falling back`)
      return await handleOpenWeatherFallback(lat, lon)
    }
    
    const data = await response.json()
    const current = data.currentWeather
    const hourly = data.forecastHourly?.hours?.[0]
    
    // 判断是否下雨
    const rainConditions = ['Rain', 'Drizzle', 'Showers', 'Thunderstorms', 'Snow']
    const isRaining = rainConditions.some(c => 
      current.conditionCode?.includes(c)
    ) || (current.precipitationIntensity && current.precipitationIntensity > 0)
    
    return {
      currentTempC: current.temperature,
      conditionText: translateCondition(current.conditionCode),
      conditionIcon: current.conditionCode,
      isRainingNow: isRaining,
      nextHourRainProbability: hourly?.precipitationChance ? Math.round(hourly.precipitationChance * 100) : null,
      nextHourPrecipMM: hourly?.precipitationAmount || null,
      source: 'WeatherKit'
    }
  } catch (e) {
    console.warn(`[WeatherKit] Error: ${e}, falling back`)
    return await handleOpenWeatherFallback(lat, lon)
  }
}

// OpenWeather 作为海外备用
async function handleOpenWeatherFallback(lat: number, lon: number): Promise<WeatherResponse> {
  console.log(`[OpenWeather] Fallback for: ${lat}, ${lon}`)
  
  if (!OPENWEATHER_API_KEY) {
    console.warn('[OpenWeather] API key not configured, returning mock data')
    return getMockWeather()
  }
  
  try {
    // 获取当前天气
    const currentUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${OPENWEATHER_API_KEY}&units=metric&lang=zh_cn`
    console.log(`[OpenWeather] Fetching: ${currentUrl.replace(OPENWEATHER_API_KEY || '', '***')}`)
    
    const currentResponse = await fetch(currentUrl)
    const currentData = await currentResponse.json()
    
    console.log(`[OpenWeather] Response cod: ${currentData.cod}, type: ${typeof currentData.cod}`)
    
    // OpenWeather 返回的 cod 可能是数字或字符串
    if (currentData.cod != 200) {
      console.error(`[OpenWeather] API error: ${currentData.cod} - ${currentData.message}`)
      throw new Error(`OpenWeather error: ${currentData.message}`)
    }
    
    // 获取小时预报
    let nextHourRainProb: number | null = null
    let nextHourPrecip: number | null = null
    
    try {
      const forecastUrl = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${OPENWEATHER_API_KEY}&units=metric&lang=zh_cn&cnt=2`
      const forecastResponse = await fetch(forecastUrl)
      const forecastData = await forecastResponse.json()
      
      if (forecastData.list?.length > 0) {
        const next = forecastData.list[0]
        nextHourRainProb = next.pop ? Math.round(next.pop * 100) : null
        nextHourPrecip = next.rain?.['3h'] ? next.rain['3h'] / 3 : null
      }
    } catch (e) {
      console.warn(`[OpenWeather] Forecast failed: ${e}`)
    }
    
    const weather = currentData.weather[0]
    const rainConditions = ['Rain', 'Drizzle', 'Thunderstorm', 'Snow']
    const isRaining = rainConditions.includes(weather.main) || 
                      (currentData.rain && currentData.rain['1h'] > 0)
    
    return {
      currentTempC: currentData.main.temp,
      conditionText: weather.description,
      conditionIcon: weather.icon,
      isRainingNow: isRaining,
      nextHourRainProbability: nextHourRainProb,
      nextHourPrecipMM: nextHourPrecip,
      source: 'WeatherKit' // 标记为 WeatherKit（因为是海外备用）
    }
  } catch (e) {
    console.error(`[OpenWeather] Error: ${e}`)
    return getMockWeather()
  }
}

// 翻译 WeatherKit 天气状况
function translateCondition(code: string): string {
  const translations: Record<string, string> = {
    'Clear': '晴朗',
    'Cloudy': '多云',
    'MostlyClear': '晴间多云',
    'MostlyCloudy': '阴',
    'PartlyCloudy': '多云',
    'Rain': '雨',
    'HeavyRain': '大雨',
    'Drizzle': '毛毛雨',
    'Showers': '阵雨',
    'Thunderstorms': '雷阵雨',
    'Snow': '雪',
    'Flurries': '小雪',
    'Fog': '雾',
    'Haze': '霾',
    'Wind': '大风',
  }
  return translations[code] || code
}

// Mock 数据
function getMockWeather(): WeatherResponse {
  const hour = new Date().getHours()
  let temp: number
  let condition: string
  
  if (hour >= 6 && hour < 12) {
    temp = 20
    condition = '晴朗'
  } else if (hour >= 12 && hour < 18) {
    temp = 26
    condition = '多云'
  } else {
    temp = 18
    condition = '晴朗'
  }
  
  return {
    currentTempC: temp,
    conditionText: condition,
    conditionIcon: null,
    isRainingNow: false,
    nextHourRainProbability: 10,
    nextHourPrecipMM: 0,
    source: 'Mock'
  }
}

// 主处理函数
serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()
  
  // 打印环境变量状态（调试用）
  console.log(`[Weather] ENV Check:`)
  console.log(`  - QWEATHER_HOST: ${QWEATHER_HOST ? '✓ configured' : '✗ not set'}`)
  console.log(`  - QWEATHER_API_KEY: ${QWEATHER_API_KEY ? '✓ configured' : '✗ not set'}`)
  console.log(`  - OPENWEATHER_API_KEY: ${OPENWEATHER_API_KEY ? '✓ configured' : '✗ not set'}`)
  console.log(`  - WEATHERKIT_AUTH_KEY: ${WEATHERKIT_AUTH_KEY ? '✓ configured' : '✗ not set'}`)
  
  try {
    const body: WeatherRequest = await req.json()
    const { latitude, longitude, provider } = body
    
    console.log(`[Weather] Request: provider=${provider}, lat=${latitude}, lon=${longitude}`)
    
    if (!latitude || !longitude) {
      throw new Error('缺少经纬度参数')
    }
    
    let result: WeatherResponse
    
    if (provider === 'qweather') {
      result = await handleQWeather(latitude, longitude)
    } else {
      result = await handleWeatherKit(latitude, longitude)
    }
    
    const elapsed = Date.now() - startTime
    console.log(`[Weather] ✅ Done in ${elapsed}ms: ${result.conditionText}, ${result.currentTempC}°C, source: ${result.source}`)
    
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    const elapsed = Date.now() - startTime
    console.error(`[Weather] ❌ Error in ${elapsed}ms:`, error.message)
    
    // 返回 mock 数据而不是错误，保证 App 体验
    const mockResult = getMockWeather()
    
    return new Response(JSON.stringify(mockResult), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
