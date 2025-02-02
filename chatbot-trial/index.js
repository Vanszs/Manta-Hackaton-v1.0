import OpenAI from "openai"

const openai = new OpenAI({
  baseURL: "https://openrouter.ai/api/v1",
  apiKey: "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",

})

async function main() {
  const completion = await openai.chat.completions.create({
    model: "openai/gpt-3.5-turbo",
    messages: [
      {
        "role": "user",
        "content": "What is the meaning of life?"
      }
    ]
  })

  console.log(completion.choices[0].message)
}
main()