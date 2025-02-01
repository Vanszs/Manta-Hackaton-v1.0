import { HfInference } from "@huggingface/inference";

const client = new HfInference("");

const chatCompletion = await client.chatCompletion({
	model: "meta-llama/Llama-2-7b-chat-hf",
	messages: [
		{
			role: "user",
			content: "What is the capital of France?"
		}
	],
	provider: "together",
	max_tokens: 500
});

console.log(chatCompletion.choices[0].message);