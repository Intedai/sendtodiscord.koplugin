# SendToDiscord KOReader Plugin
SendToDiscord lets you send highlighted text and text from your clipboard to Discord in beautiful embeds using webhooks.  

<img width="413" height="170" alt="Screenshot from 2026-07-23 03-00-12" src="https://github.com/user-attachments/assets/2a175e44-ad19-4577-8327-ae786119f278" />


## Installation
1. Download `sendtodiscord.koplugin.zip` from the latest release in the [Releases](https://github.com/Intedai/sendtodiscord.koplugin/releases) page
2. Unzip the archive and move `sendtodiscord.koplugin` to the plugins directory (`koreader/plugins`)

## Setup
1. [Create a webhook](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)
2. Go to Tools -> More Tools -> SendToDiscord
<img width="2056" height="549" alt="find_sendtodiscord" src="https://github.com/user-attachments/assets/aa697b40-bf04-4d1f-af77-8fa253a0274b" />
3. Now go to Settings -> Webhook URL and enter your webhook url

(You can create a text file in your koreader folder with the url and copy paste it instead of writing the url manually)

<img width="1362" height="336" alt="webhook_url" src="https://github.com/user-attachments/assets/c8e242e5-cdca-48e2-8431-e6d3d7e019bb" />

## Showcase
### Send highlighted text to Discord:
<img width="708" height="411" alt="highlight" src="https://github.com/user-attachments/assets/28748b55-d341-439d-9e20-b6968ae2b97f" />
<BR>
<img width="509" height="143" alt="image" src="https://github.com/user-attachments/assets/c4cb0777-ebcd-40be-b81c-21755a394fd0" />

### Send text from clipboard:
<img width="684" height="337" alt="clipboard" src="https://github.com/user-attachments/assets/5e5180e8-5883-461c-96f4-67c9b04f2e43" />
<BR>
<img width="129" height="141" alt="image" src="https://github.com/user-attachments/assets/d4376519-e339-4b47-a72a-f884ff3bf70e" />

### Change the embed's color:
<img width="1280" height="371" alt="colorchange" src="https://github.com/user-attachments/assets/a06d1554-36b8-43f6-9b41-a3b1b55233a7" />
<BR>
<img width="149" height="147" alt="image" src="https://github.com/user-attachments/assets/c9d2d594-5865-4be2-acbf-1f89e11ed6fd" />

### Add a suffix and prefix to the text:
<img width="1431" height="374" alt="presuff" src="https://github.com/user-attachments/assets/8a9e14df-a561-4ccc-9b21-b95f1c3f7440" />
<BR>  

For example adding quotation marks:  

<img width="413" height="170" alt="Screenshot from 2026-07-23 03-00-12" src="https://github.com/user-attachments/assets/2a175e44-ad19-4577-8327-ae786119f278" />

### Use space encoding:
<img width="1807" height="441" alt="encode" src="https://github.com/user-attachments/assets/1526fcd8-f518-4936-b535-b4e8bfe5ce39" />
<BR>  

For example we can choose `%20` for the space encoding with the prefix: `[prompt](https://www.chatgpt.com/?prompt=Explain%20this:%20` and the suffix: `)`:  

<img width="174" height="150" alt="image" src="https://github.com/user-attachments/assets/6a0c6eed-acef-4436-b398-0cb86d3e92a6" />  

And when opening the link we get this:  

<img width="847" height="124" alt="image" src="https://github.com/user-attachments/assets/d75a0458-986d-4136-a988-674db4433482" />

### Preserve whitespaces by wrapping the text in a code block:
Use this instead of manually wrapping the text with prefix and suffix because it executes different code and whitespaces won't be preserved otherwise!  

<img width="1431" height="374" alt="codeblock" src="https://github.com/user-attachments/assets/c7a68380-99d0-4455-b897-ed420342450d" />
<BR>  

<img width="332" height="238" alt="image" src="https://github.com/user-attachments/assets/93a96808-ee6a-4c88-9cd8-f7f67ae75e3a" />






