from transformers import AutoModelForCausalLM, AutoTokenizer
import torch


tokenizer = AutoTokenizer.from_pretrained('output-medium/checkpoint-7000')
model = AutoModelForCausalLM.from_pretrained('output-medium/checkpoint-7000')

#device = torch.device("cpu")
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(device)
if device.type == "cuda":
    model.to(device)

user_input = ""
repeat = 3
#step = 0
while True:
    step = 0
    user_input = input(">> User: ")
    if user_input == "exit":
        break
    # encode the new user input, add the eos_token and return a tensor in Pytorch
    for i in range(repeat):
        print()
        new_user_input_ids = tokenizer.encode(user_input + tokenizer.eos_token, return_tensors='pt')
    
        # append the new user input tokens to the chat history
        bot_input_ids = torch.cat([chat_history_ids[0:1], new_user_input_ids], dim=-1) if step > 0 else new_user_input_ids
        #print ("Model Input: {}".format(tokenizer.decode(bot_input_ids[0])))
        #print()
        
        if device.type == "cuda":
            bot_input_ids = bot_input_ids.to(device)
    
        # generated a response while limiting the total chat history to 1000 tokens, 
        chat_history_ids = model.generate(bot_input_ids, 
                                          max_length=1000,
                                          pad_token_id=tokenizer.eos_token_id,
                                          no_repeat_ngram_size=3,
                                          length_penalty=1.0,
                                          do_sample=True,
                                          temperature=1.2,
                                          num_beams=3,
                                          num_return_sequences=1)
        
        if device.type == "cuda":
            chat_history_ids = chat_history_ids.to("cpu")
    
        # pretty print last ouput tokens from bot
        for i in range(chat_history_ids.shape[0]):
            print("DialoGPT: {}".format(tokenizer.decode(chat_history_ids[:, bot_input_ids.shape[-1]:][i], skip_special_tokens=True)))
    step += 1