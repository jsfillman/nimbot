import os, times, terminal, strutils, httpclient, json

const API_URL = "https://api.openai.com/v1/chat/completions"
const SYSTEM_PROMPT_FILE = "gpt_instructions.md"  # Path to system prompt

proc getEnvVar(key: string): string =
  let value = getEnv(key)
  if value.len == 0:
    raise newException(ValueError, "Missing API Key. Set " & key & " as an environment variable.")
  return value

let apiKey = getEnvVar("OPENAI_API_KEY")

proc readFileContent(filePath: string): string =
  try:
    return readFile(filePath).strip()
  except CatchableError:
    raise newException(ValueError, "Error: Unable to load " & filePath)

proc gptRequest(messages: seq[JsonNode]): string =
  let client = newHttpClient()
  client.headers = newHttpHeaders({
    "Authorization": "Bearer " & apiKey,
    "Content-Type": "application/json"
  })

  let body = %*{
    "model": "gpt-4o",
    "messages": messages
  }

  let response = client.postContent(API_URL, $body)
  client.close()  # 🔹 Close the client to prevent open handles

  let jsonResponse = parseJson(response)
  return jsonResponse["choices"][0]["message"]["content"].getStr()



proc displayText(text: string, delay: float = 0.02) =
  for char in text:
    stdout.write char
    stdout.flushFile()
    sleep(int(delay * 1000))
  echo ""

proc chatInterface() =
  echo "\e[1;36mCustom GPT Chat Interface - Type 'exit' to quit.\e[0m"

  let systemPrompt = readFileContent(SYSTEM_PROMPT_FILE)
  var conversationHistory = @[
    %*{"role": "system", "content": systemPrompt}
  ]

  # 🎙️ Make the bot speak first!
  try:
    let firstMessage = gptRequest(conversationHistory)
    conversationHistory.add(%*{"role": "assistant", "content": firstMessage})
    displayText("\e[1;34mGPT:\e[0m " & firstMessage)
  except CatchableError as e:
    echo "\e[1;31mError:\e[0m ", e.msg
    return  # Exit gracefully if OpenAI API fails

  # 🟢 Now enter the chat loop
  while true:
    stdout.write "\e[1;32mYou:\e[0m "
    stdout.flushFile()
    let userInput = readLine(stdin).strip()

    if userInput.toLower() in ["exit", "quit"]:
      echo "\e[1;31mGoodbye! 👋\e[0m"
      return  # 🔹 Gracefully exit instead of breaking the loop

    conversationHistory.add(%*{"role": "user", "content": userInput})

    try:
      let answer = gptRequest(conversationHistory)
      conversationHistory.add(%*{"role": "assistant", "content": answer})
      displayText("\e[1;34mGPT:\e[0m " & answer)
    except CatchableError as e:
      echo "\e[1;31mError:\e[0m ", e.msg
      return  # Exit on fatal error


when isMainModule:
  chatInterface()
