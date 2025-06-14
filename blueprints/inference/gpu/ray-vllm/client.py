from openai import OpenAI

model = "" # model name in org/model format
port = "" # port number being forwarded
prompt = "Hello" # prompt
client = OpenAI(
    base_url=f"http://localhost:{port}/v1",
    api_key="token",
)

# Chat Completion
response = client.chat.completions.create(
    model=model,
    messages=[
        {"role": "user", "content": f"{prompt}"}
    ]
)
print(response.choices[0].message)

# Completions

# response = client.completions.create(
#     model=model,
#     prompt=prompt
# )
# print(response.choices[0].text)
